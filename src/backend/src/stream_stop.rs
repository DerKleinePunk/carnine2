//! Ends every open gRPC response when the backend stops.
//!
//! The frontend keeps server streams open (status, events, positions) that
//! never end by themselves, so the graceful shutdown waited its full 5 s for
//! them on every stop. [`StopStreamsLayer`] wraps each response body; once
//! the stop is signalled, a body still running ends with the status
//! UNAVAILABLE in its trailers, and the server finishes at once.
//!
//! UNAVAILABLE and not a clean end: the frontend's media controllers set up
//! their streams again only on an error, so to them a stop looks like the
//! dropped connection it was before.

use std::pin::Pin;
use std::task::{Context, Poll};

use futures_util::future::BoxFuture;
use http_body::{Body, Frame, SizeHint};
use tokio::sync::watch;
use tonic::Status;

const STOPPING: &str = "backend is stopping";

/// Signals the stop to every response wrapped by the layers made from it.
pub struct StreamStop {
    stopped: watch::Sender<bool>,
}

impl StreamStop {
    pub fn new() -> Self {
        Self {
            stopped: watch::channel(false).0,
        }
    }

    pub fn layer(&self) -> StopStreamsLayer {
        StopStreamsLayer {
            stopped: self.stopped.subscribe(),
        }
    }

    /// Ends the running responses; responses started later end at once.
    pub fn stop(&self) {
        self.stopped.send_replace(true);
    }
}

#[derive(Clone)]
pub struct StopStreamsLayer {
    stopped: watch::Receiver<bool>,
}

impl<S> tower_layer::Layer<S> for StopStreamsLayer {
    type Service = StopStreams<S>;

    fn layer(&self, inner: S) -> Self::Service {
        StopStreams {
            inner,
            stopped: self.stopped.clone(),
        }
    }
}

#[derive(Clone)]
pub struct StopStreams<S> {
    inner: S,
    stopped: watch::Receiver<bool>,
}

impl<S, Request, B> tower_service::Service<Request> for StopStreams<S>
where
    S: tower_service::Service<Request, Response = http::Response<B>>,
    S::Future: Send + 'static,
{
    type Response = http::Response<StoppableBody<B>>;
    type Error = S::Error;
    type Future = BoxFuture<'static, Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, request: Request) -> Self::Future {
        let response = self.inner.call(request);
        let stopped = self.stopped.clone();
        Box::pin(async move {
            Ok(response
                .await?
                .map(|body| StoppableBody::new(body, stopped)))
        })
    }
}

/// A response body that ends with UNAVAILABLE once the stop is signalled.
pub struct StoppableBody<B> {
    inner: B,
    stopped: BoxFuture<'static, ()>,
    done: bool,
}

impl<B> StoppableBody<B> {
    fn new(inner: B, mut stopped: watch::Receiver<bool>) -> Self {
        Self {
            inner,
            stopped: Box::pin(async move {
                // A dropped sender never stops anything.
                if stopped.wait_for(|stopped| *stopped).await.is_err() {
                    std::future::pending::<()>().await;
                }
            }),
            done: false,
        }
    }
}

impl<B> Body for StoppableBody<B>
where
    B: Body + Unpin,
{
    type Data = B::Data;
    type Error = B::Error;

    fn poll_frame(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
    ) -> Poll<Option<Result<Frame<Self::Data>, Self::Error>>> {
        if self.done {
            return Poll::Ready(None);
        }
        if self.stopped.as_mut().poll(cx).is_ready() {
            self.done = true;
            let mut trailers = http::HeaderMap::new();
            // The message is plain ASCII, so the header cannot fail.
            let _ = Status::unavailable(STOPPING).add_header(&mut trailers);
            return Poll::Ready(Some(Ok(Frame::trailers(trailers))));
        }
        let frame = Pin::new(&mut self.inner).poll_frame(cx);
        match &frame {
            // The inner body said its last word: its own status stands.
            Poll::Ready(None) => self.done = true,
            Poll::Ready(Some(Ok(frame))) if frame.is_trailers() => self.done = true,
            _ => {}
        }
        frame
    }

    fn is_end_stream(&self) -> bool {
        self.done || self.inner.is_end_stream()
    }

    fn size_hint(&self) -> SizeHint {
        self.inner.size_hint()
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;
    use crate::carnine::audio_service_client::AudioServiceClient;
    use crate::carnine::audio_service_server::AudioServiceServer;
    use crate::carnine::Empty;
    use http_body_util::BodyExt;
    use tokio_stream::StreamExt;

    type Frames =
        Pin<Box<dyn tokio_stream::Stream<Item = Result<Frame<bytes::Bytes>, Status>> + Send>>;

    /// A body that sends one chunk and then nothing, like an idle event stream.
    fn idle_stream() -> http_body_util::StreamBody<Frames> {
        let first = tokio_stream::once(Ok(Frame::data(bytes::Bytes::from_static(b"first"))));
        http_body_util::StreamBody::new(Box::pin(first.chain(tokio_stream::pending())))
    }

    fn status_in(trailers: &http::HeaderMap) -> Option<&str> {
        trailers
            .get("grpc-status")
            .and_then(|value| value.to_str().ok())
    }

    #[tokio::test]
    async fn an_idle_stream_ends_with_unavailable_on_stop() {
        let stop = StreamStop::new();
        let mut body = StoppableBody::new(idle_stream(), stop.stopped.subscribe());
        let first = body.frame().await.unwrap().unwrap();
        assert_eq!(first.into_data().unwrap(), "first");
        let waiting = tokio::time::timeout(Duration::from_millis(100), body.frame()).await;
        assert!(waiting.is_err(), "nothing comes before the stop");

        stop.stop();
        let last = body.frame().await.unwrap().unwrap();
        assert_eq!(status_in(last.trailers_ref().unwrap()), Some("14"));
        assert!(body.frame().await.is_none());
        assert!(body.is_end_stream());
    }

    #[tokio::test]
    async fn a_finished_response_keeps_its_own_status() {
        let stop = StreamStop::new();
        let mut trailers = http::HeaderMap::new();
        Status::ok("").add_header(&mut trailers).unwrap();
        let frames: Vec<Result<Frame<bytes::Bytes>, Status>> = vec![
            Ok(Frame::data(bytes::Bytes::from_static(b"reply"))),
            Ok(Frame::trailers(trailers)),
        ];
        let mut body = StoppableBody::new(
            http_body_util::StreamBody::new(tokio_stream::iter(frames)),
            stop.stopped.subscribe(),
        );
        body.frame().await.unwrap().unwrap();
        let own = body.frame().await.unwrap().unwrap();
        assert_eq!(status_in(own.trailers_ref().unwrap()), Some("0"));

        stop.stop();
        assert!(
            body.frame().await.is_none(),
            "no second status after the stop"
        );
    }

    #[tokio::test]
    async fn without_a_stop_nothing_changes() {
        let stop = StreamStop::new();
        let mut body = StoppableBody::new(idle_stream(), stop.stopped.subscribe());
        drop(stop);
        body.frame().await.unwrap().unwrap();
        let waiting = tokio::time::timeout(Duration::from_millis(100), body.frame()).await;
        assert!(waiting.is_err(), "a dropped stop does not end the stream");
    }

    /// The whole way: a real server with an open event stream stops at once,
    /// and the client sees UNAVAILABLE. Without the layer the same server is
    /// still waiting for the stream after a second.
    async fn stop_with_an_open_stream(with_layer: bool) -> (bool, Option<tonic::Code>) {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let incoming = tokio_stream::wrappers::TcpListenerStream::new(listener);
        let stop = StreamStop::new();
        let (shutdown, shutdown_receiver) = tokio::sync::oneshot::channel::<()>();
        let signal = async move {
            let _ = shutdown_receiver.await;
        };
        let service = AudioServiceServer::new(crate::AudioServiceImpl::new());
        let server: BoxFuture<'static, Result<(), tonic::transport::Error>> = if with_layer {
            Box::pin(
                tonic::transport::Server::builder()
                    .layer(stop.layer())
                    .add_service(service)
                    .serve_with_incoming_shutdown(incoming, signal),
            )
        } else {
            Box::pin(
                tonic::transport::Server::builder()
                    .add_service(service)
                    .serve_with_incoming_shutdown(incoming, signal),
            )
        };
        let server = tokio::spawn(server);

        let mut client = AudioServiceClient::connect(format!("http://{address}"))
            .await
            .unwrap();
        let mut events = client
            .stream_audio_events(Empty {})
            .await
            .unwrap()
            .into_inner();
        events.message().await.unwrap().expect("the opening event");
        let ended = tokio::spawn(async move { events.message().await.err().map(|e| e.code()) });

        stop.stop();
        let _ = shutdown.send(());
        let finished = tokio::time::timeout(Duration::from_secs(1), server)
            .await
            .is_ok();
        let code = tokio::time::timeout(Duration::from_secs(1), ended)
            .await
            .ok()
            .and_then(|result| result.ok())
            .flatten();
        (finished, code)
    }

    #[tokio::test]
    async fn a_server_with_an_open_stream_stops_at_once() {
        let (finished, code) = stop_with_an_open_stream(true).await;
        assert!(finished, "the server finishes within a second");
        assert_eq!(code, Some(tonic::Code::Unavailable));
    }

    #[tokio::test]
    async fn without_the_layer_the_open_stream_holds_the_server() {
        let (finished, _) = stop_with_an_open_stream(false).await;
        assert!(!finished, "the stream keeps the server waiting");
    }
}

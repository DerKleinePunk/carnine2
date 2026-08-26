use std::sync::Arc;

use anyhow::Result;
use futures_util::StreamExt;
use tracing::{error, info, warn};
use zbus::{message::Type, Connection, MatchRule, MessageStream};

use crate::MediaServiceImpl;

pub fn spawn(media_service: Arc<MediaServiceImpl>) {
    tokio::spawn(async move {
        if let Err(error) = listen(media_service).await {
            warn!(%error, "storage event listener stopped");
        }
    });
}

async fn listen(media_service: Arc<MediaServiceImpl>) -> Result<()> {
    let connection = Connection::system().await?;
    let rule = MatchRule::builder()
        .msg_type(Type::Signal)
        .sender("org.freedesktop.UDisks2")?
        .path_namespace("/org/freedesktop/UDisks2")?
        .build();
    info!("udisks2 storage event listener started");
    let mut messages = MessageStream::for_match_rule(rule, &connection, Some(32)).await?;
    while let Some(message) = messages.next().await {
        let message = message?;
        let header = message.header();
        if header.primary().msg_type() != Type::Signal {
            continue;
        }
        let Some(member) = header.member() else {
            continue;
        };
        if !matches!(
            member.as_str(),
            "InterfacesAdded" | "InterfacesRemoved" | "PropertiesChanged"
        ) {
            continue;
        }

        info!(event = %member, "udisks2 storage event received; rescanning media");
        if let Err(error) = media_service.rescan_library() {
            error!(%error, "automatic media rescan failed after storage event");
        }
    }

    Ok(())
}
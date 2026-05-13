# Build an CarPC Software for Raspberry 4
Yes i Try Build in with KI this is the Second Reason for create this Repro

## Setup

Before building, ensure you have the required build dependencies installed. See the specific README files for each component:

- [Backend Setup](src/backend/README.md#build-dependencies)
- [Frontend Setup](src/frontend/README.md#build-dependencies)

The root build scripts `build_linux.sh` and `build_pi.sh` generate Dart gRPC stubs from the shared schema at `src/proto/carnine.proto`.

## Architecture Documentation

See the [Arc42 documentation](docs/README.md) for detailed architectural information about the project.

## Resources

- [Sound Resources](resources/sounds/README.md) - Audio files for notifications and UI feedback

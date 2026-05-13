## Project Overview

Modern application with Flutter frontend and Rust backend.

## Important Files - READ BEFORE WORKING

⚠️ **Always review these files before starting work**:

### Agent Configuration Files (AGENTS.md)
- **Root**: This file - main project agent configuration
- **Backend**: [src/backend/AGENTS.md](src/backend/AGENTS.md) - Backend-specific conventions
- **Frontend**: [src/frontend/AGENTS.md](src/frontend/AGENTS.md) - Frontend-specific conventions

These files contain important development patterns, coding conventions, and architectural guidelines that must be followed.

### Architecture Documentation (arc42)
- **Main**: [docs/README.md](docs/README.md) - Documentation index
- **Architecture Decisions**: [docs/09-architecture-decisions.md](docs/09-architecture-decisions.md) - ADRs
- **Solution Strategy**: [docs/04-solution-strategy.md](docs/04-solution-strategy.md)
- **Building Blocks**: [docs/05-building-block.md](docs/05-building-block.md)

This is the single source of truth for how the system is designed and why decisions were made.

## Project Structure

```
carnine2/
├── src/
│   ├── backend/          # Rust backend
│   ├── frontend/         # Flutter frontend
│   └── proto/            # Protobuf definitions
├── docs/                 # arc42 documentation
├── CONTRIBUTING.md       # How to contribute
├── CODE_OF_CONDUCT.md    # Code of conduct
└── AGENTS.md            # This file
```

## Development Guidelines

1. **Read the relevant AGENTS.md** before making changes
2. **Check arc42 documentation** for architectural context
3. **Follow CONTRIBUTING.md** guidelines for pull requests
4. **Respect the Code of Conduct** in all interactions

## Quick Links

- 🏗️ [Architecture Documentation](docs/README.md)
- 🔧 [Backend README](src/backend/README.md)
- 📱 [Frontend README](src/frontend/README.md)
- 📖 [Contributing Guide](CONTRIBUTING.md)

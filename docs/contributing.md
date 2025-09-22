# Contributing

We welcome contributions to beatz! This document outlines our development process and guidelines.

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ghostkellz/beatz.git
   cd beatz
   ```

2. **Build and test**:
   ```bash
   zig build
   zig build test
   ```

## Code Style

beatz follows standard Zig conventions:

- Use `zig fmt` for code formatting
- 4-space indentation
- Descriptive variable names
- Comprehensive error handling
- Memory safety first

## Pull Request Process

1. **Fork** the repository
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes** with tests
4. **Run tests**: `zig build test`
5. **Update documentation** if needed
6. **Commit** with clear messages
7. **Push** to your fork
8. **Create a Pull Request**

## Testing

- Add unit tests for new functionality
- Test on multiple platforms when possible
- Include integration tests for complex features
- Ensure all tests pass before submitting

## Documentation

- Update relevant docs in `docs/` for API changes
- Add code comments for complex logic
- Update examples if new features are added

## Platform-Specific Code

When adding platform backends:

- Keep platform code isolated in `src/backends/`
- Use conditional compilation (`builtin.target`)
- Provide fallbacks for unsupported platforms
- Test on target platforms

## Commit Messages

Use clear, descriptive commit messages:

```
feat: add WASAPI backend for Windows
fix: handle buffer underrun in PipeWire stream
docs: update API reference for new functions
```

## Code Review

All PRs require review. Reviewers will check for:

- Code correctness and safety
- Performance implications
- API consistency
- Test coverage
- Documentation updates

## Issue Reporting

When reporting bugs:

- Include Zig version: `zig version`
- Specify platform and backend
- Provide minimal reproduction code
- Include error messages and stack traces

## Feature Requests

For new features:

- Check if it fits beatz's scope (device I/O focus)
- Consider if it belongs in zcodec or zdsp instead
- Provide use case and API design
- Start with an issue discussion

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
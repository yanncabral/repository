# Repository

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![License: MIT][license_badge]][license_link]

A reactive repository toolkit for Flutter with HTTP, caching, dependency tracking, auto refresh, and UI integration.

## Warning ⚠️

This package is currently under heavy development and is **not yet ready for production use**. It is being actively worked on by our development team, and we are constantly adding new features and making improvements.

While we are working hard to make this package as stable and reliable as possible, there may be bugs or issues that arise as new code is added or existing code is modified. We encourage you to report any issues you encounter during this development process, and we will do our best to address them as quickly as possible.

As we continue to develop this package, we may make breaking changes to the API or other aspects of the package. We will do our best to document any such changes and provide guidance on how to update your code accordingly.

We appreciate your patience and understanding as we work to bring this package to maturity. We are committed to delivering a high-quality, reliable package that meets the needs of our users, and we believe that with your feedback and support, we can achieve that goal.

## Installation 💻

**❗ Repository now includes its Flutter integration, so a Flutter SDK is required.**

Add `repository` to your `pubspec.yaml`:

```yaml
dependencies:
  repository: ^4.0.0-dev.1
```

Install it:

```sh
flutter pub get
```

---

## Continuous Integration 🤖

Repository comes with a built-in [GitHub Actions workflow][github_actions_link] powered by [Very Good Workflows][very_good_workflows_link] but you can also add your preferred CI/CD solution.

Out of the box, on each pull request and push, the CI `formats`, `lints`, and `tests` the code. This ensures the code remains consistent and behaves correctly as you add functionality or make changes. The project uses [Very Good Analysis][very_good_analysis_link] for a strict set of analysis options used by our team. Code coverage is enforced using the [Very Good Workflows][very_good_coverage_link].

---

## Running Tests 🧪

To run all unit tests:

```sh
flutter test --coverage
```

To view the generated coverage report you can use [lcov](https://github.com/linux-test-project/lcov).

```sh
# Generate Coverage Report
genhtml coverage/lcov.info -o coverage/

# Open Coverage Report
open coverage/index.html
```

[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[logo_black]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_black.png#gh-light-mode-only
[logo_white]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_white.png#gh-dark-mode-only
[mason_link]: https://github.com/felangel/mason
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_coverage_link]: https://github.com/marketplace/actions/very-good-coverage
[very_good_ventures_link]: https://verygood.ventures
[very_good_ventures_link_light]: https://verygood.ventures#gh-light-mode-only
[very_good_ventures_link_dark]: https://verygood.ventures#gh-dark-mode-only
[very_good_workflows_link]: https://github.com/VeryGoodOpenSource/very_good_workflows

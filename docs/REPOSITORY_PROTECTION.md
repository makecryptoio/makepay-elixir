# Repository Protection

The GitHub repository should use:

- Public visibility.
- Issues enabled and wiki disabled.
- Squash merge enabled.
- Automatic branch deletion after merge.
- Dependabot security alerts and security fixes enabled.
- GitHub Actions workflow token restricted to read-only contents access.
- `main` branch protection requiring:
  - `validate` status check.
  - Linear history.
  - No force pushes.
  - No deletions.
  - Conversation resolution.
  - One approving pull request review.

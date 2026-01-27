# Contributing to x-ALP

Thank you for your interest in contributing to x-ALP! We welcome contributions from the community. Please follow the procedure below to ensure a smooth contribution process.

## Contribution Procedure

### 1. Open an Issue

Before starting work on a new feature or bug fix, please open an issue to discuss your proposed changes:

- Navigate to the [Issues](../../issues) page
- Click "New Issue"
- Describe the problem, feature request, or improvement you'd like to propose
- Provide context and any relevant details
- Wait for feedback from maintainers before proceeding

### 2. Fork the Repository

Once your issue has been acknowledged:

- Click the "Fork" button on the repository page
- This creates a personal copy of the repository under your GitHub account
- Clone your fork to your local machine:
  ```bash
  git clone https://github.com/YOUR_USERNAME/x-alp.git
  cd x-alp
  ```

### 3. Create a Branch

Create a new branch for your work:

- Use a descriptive branch name that references the issue:
  ```bash
  git checkout -b issue-#<issue-number>-brief-description
  ```
  Example: `git checkout -b issue-#42-fix-simulation-timing`
- Keep your branch focused on a single issue or feature

### 4. Make Your Changes and Create a Pull Request (WIP Mode)

Develop your solution and commit your changes:

- Make logical, atomic commits with clear messages
- Push your branch to your fork:
  ```bash
  git push origin issue-#<issue-number>-brief-description
  ```
- Create a Pull Request (PR) in **WIP (Work In Progress)** mode:
  - Go to the original repository
  - Click "New Pull Request"
  - Select your branch to compare against `main` (or appropriate base branch)
  - In the PR title, prefix with `WIP:` to indicate it's still under development:
    ```
    WIP: Brief description of changes
    ```
  - In the PR description, include:
    - A brief summary of your changes
    - A link to the related issue: `Fixes #<issue-number>` or `Related to #<issue-number>`
    - Any relevant context or testing notes

### 5. Open the PR for Review

When your work is ready for feedback:

- Update the PR title to remove the `WIP:` prefix
- Request reviewers from the maintainers
- Be responsive to feedback and make requested changes
- Maintainers will review your contribution and provide guidance

## Guidelines

- **Code Style**: Follow the existing code style and conventions in the repository
- **Testing**: Ensure your changes don't break existing functionality
- **Documentation**: Update relevant documentation if your changes require it
- **Commit Messages**: Write clear, descriptive commit messages
- **Scope**: Keep changes focused and manageable

## Questions?

If you have any questions or need clarification, feel free to:
- Post a comment on the related issue
- Reach out to the maintainers
- Check the [README](README.md) and other documentation

Thank you for contributing to x-ALP!

# Contributing Guidelines

## 1. Overview
This repository contains the **Smart WIC Cart** project for CSC 510 – Software Engineering at NC State University.  

---

## 2. Code of Conduct
- Be respectful and professional in all communication.  
- Keep all collaboration within GitHub Issues and Pull Requests.  
- Review others’ code carefully before approving merges.

## 3. Project Setup

### Clone the repository
```bash
git clone https://github.com/SuyeshJadhav/CSC510_G19.git
cd Project2/
````

### For Flutter frontend

```bash
flutter pub get
flutter run -d chrome
```

### For backend

```bash
pip install -r requirements.txt
```

---

## 4. Branching and Workflow

| Type          | Example                                 |
| ------------- | --------------------------------------- |
| Main branch   | `main`                                  |
| Frontend work | `frontend`                              |
| Backend work  | `backend`                               |
| Docs          | `Documentation and readme updates`       |

### Create and push a feature branch

```bash
git checkout -b feature/<short-description>
git add .
git commit -m "feat: short summary"
git push -u origin feature/<short-description>
```

---

## 5. Commit Message Format

Follow Conventional Commits:

```
<type>(<scope>): <summary>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

**Examples:**

```
feat(scan): add barcode scanner screen
fix(firebase): correct document path
docs(contributing): update setup steps
```

---

## 6. Pull Request Process

1. Pull latest changes from `main`.
2. Ensure code compiles and tests pass.
3. Create a PR with a clear title and description.
4. Link related issues (e.g., “Closes #5”).
5. Request a review from another contributor.
6. Merge only after review approval and passing CI checks.

---

## 7. Coding Standards

* Use clear, consistent naming (snake_case for files, PascalCase for classes).
* Run `flutter analyze` or `dart format` before committing.
* Keep widgets and functions modular.
* Add comments for complex logic.

---

## 8. Testing

### Run unit and widget tests

```bash
flutter test
```

### Backend tests (if applicable)

```bash
pytest
```

Each new feature should include at least one test case.

---

## 9. Documentation

* Update `README.md` for new setup or feature instructions.
* Update this file if the contribution process changes.



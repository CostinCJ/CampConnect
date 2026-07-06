# R5 Decision Log

## Unpinned caret ranges in functions/package.json

`firebase-admin: ^12.0.0` and `firebase-functions: ^5.0.0` allow automatic minor/patch drift on a
bare `npm install`. **Decision:** no change — `package-lock.json` is committed and both the R5 CI
workflow and local dev docs use `npm ci`, which respects the lockfile exactly regardless of the
caret range. Revisit only if a contributor is ever found running `npm install` instead of `npm ci`.

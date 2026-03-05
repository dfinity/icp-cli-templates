// This script renames the `<language>-backend` directory to `backend`
// By the time this script is called the conditionals would have filtered
// all the unselected backend folders

let backend_type = variable::get("backend_type");
debug(`backend_type: ${backend_type}`);

switch backend_type {
  "rust" => {
    file::rename("rust-backend", "backend");
  }
  "motoko" => {
    file::rename("motoko-backend", "backend");
  }
}

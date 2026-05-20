// This script just renames the `<language>-backend` directory to `backend`
// and renames the `<framework>-frontend` directory to `frontend`
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

let frontend_type = variable::get("frontend_type");
debug(`frontend_type: ${frontend_type}`);
switch frontend_type {
  "react" => {
    file::rename("react-frontend", "frontend");
  }
  "vue" => {
    file::rename("vue-frontend", "frontend");
  }
}

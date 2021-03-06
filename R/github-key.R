#' SSH key helpers
#'
#' @param pubkey The public key of the SSH key pair
#' @template repo
#' @param user Personal user account to authenticate with
#' @param title The title of the key to add
#' @param check_role Whether to check if the current user has the permissions to
#' add a key to the repo. Setting this to `FALSE` makes it possible to add keys
#' to other repos than just the one from which the function is called.
#' @template remote
#' @keywords internal
#' @name ssh_key_helpers
#' @export
github_add_key <- function(pubkey,
                           repo = get_repo(remote),
                           user = get_user(),
                           title = "travis",
                           remote = "origin",
                           check_role = TRUE) {

  if (inherits(pubkey, "key")) {
    pubkey <- as.list(pubkey)$pubkey
  }
  if (!inherits(pubkey, "pubkey")) {
    stopc("`pubkey` must be an RSA/EC public key")
  }

  if (check_role) {
    # check if we have enough rights to add a key
    check_admin_repo(
      owner = get_owner(remote = remote),
      user = user,
      repo = repo
    )
  }
  key_data <- create_key_data(pubkey, title)

  # add public key to repo deploy keys on GitHub
  ret <- add_key(key_data,
    owner = get_owner(remote = remote),
    project = repo
  )

  cli::cat_rule()
  cli::cli_alert_success("Added a public deploy key to GitHub for repo
                         {.code {get_owner(remote)}/{repo}}.", wrap = TRUE)

  invisible(ret)
}

#' @param owner The owner of the repository
#' @param user The name of the user account
#' @template repo
#' @keywords internal
#' @rdname ssh_key_helpers
#' @export
check_admin_repo <- function(owner, user, repo) {
  role_in_repo <- get_role_in_repo(owner, user, repo)
  if (role_in_repo != "admin") {
    stopc(
      "Must have role 'admin' to add deploy key to repo ",
      repo, ", not '", role_in_repo, "'."
    )
  }
}

add_key <- function(key_data, owner, project) {

  resp <- gh::gh("POST /repos/:owner/:repo/keys",
    owner = owner, repo = project,
    title = key_data$title,
    key = key_data$key, read_only = key_data$read_only
  )

  invisible(resp)
}

#' @param owner The owner of the repository
#' @param user The name of the user account
#' @template repo
#' @keywords internal
#' @rdname ssh_key_helpers
#' @export
get_role_in_repo <- function(owner, user, repo) {

  req <- gh::gh("/repos/:owner/:repo/collaborators/:username/permission",
    owner = owner, repo = repo, username = user
  )
  req$permission
}

github_user <- function() {
  req <- gh::gh("GET /user")
  return(req)
}

create_key_data <- function(pubkey, title) {
  list(
    "title" = title,
    "key" = openssl::write_ssh(pubkey),
    "read_only" = FALSE
  )
}

#' @description
#' `github_repo()` returns the true repository name as string.
#'
#' @param info `[list]`\cr
#'   GitHub information for the repository, by default obtained through
#'   [github_info()].
#' @template remote
#'
#' @export
#' @keywords internal
#' @rdname github_info
github_repo <- function(path = usethis::proj_get(),
                        info = github_info(path, remote = remote),
                        remote = "origin") {
  paste(info$owner$login, info$name, sep = "/")
}

#' Github information
#'
#' @description
#' Retrieves metadata about a Git repository from GitHub.
#'
#' `github_info()` returns a list as obtained from the GET "/repos/:repo" API.
#'
#' @param path `[string]`\cr
#'   The path to a GitHub-enabled Git repository (or a subdirectory thereof).
#' @template remote
#' @family GitHub functions
#' @export
#' @keywords internal
github_info <- function(path = usethis::proj_get(),
                        remote = "origin") {
  remote_url <- get_remote_url(path, remote)
  repo <- extract_repo(remote_url)
  get_repo_data(repo)
}

#' @rdname github_info
#' @keywords internal
#' @export
uses_github <- function(path = usethis::proj_get()) {
  tryCatch(
    {
      github_info(path)
      return(invisible(TRUE))
    },
    error = function(e) {
      structure(FALSE, reason = conditionMessage(e))
    }
  )
}

get_repo_data <- function(repo) {
  req <- gh::gh("/repos/:repo", repo = repo)
  return(req)
}

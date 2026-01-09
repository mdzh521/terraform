variable eks_admins {
  type        = list(string)
  default     = ["ops",]
  description = "usernames for admin role"
}

variable registry_server {
  type        = string
  default     = ""
  description = "image registry server"
}

variable registry_username {
  type        = string
  default     = ""
  description = "image registry username"
}

variable registry_password {
  type        = string
  default     = ""
  description = "image registry password"
}

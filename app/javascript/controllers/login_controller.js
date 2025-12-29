import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "email",
    "password",
    "roleInput",
    "roleStudent",
    "roleTeacher",
    "eye",
    "eyeOff"
  ]

  connect() {
    const role = this.hasRoleInputTarget ? this.roleInputTarget.value : "student"
    this.applyRole(role || "student")
  }

  selectStudent() {
    this.applyRole("student")
  }

  selectTeacher() {
    this.applyRole("teacher")
  }

  fillDemo(event) {
    const role = event.params.role || "student"
    this.applyRole(role)

    if (this.hasEmailTarget) {
      this.emailTarget.value = role === "teacher" ? "teacher@example.com" : "student@example.com"
    }
    if (this.hasPasswordTarget) {
      this.passwordTarget.value = "password"
    }
  }

  togglePassword() {
    if (!this.hasPasswordTarget) return

    const shouldShow = this.passwordTarget.type === "password"
    this.passwordTarget.type = shouldShow ? "text" : "password"

    if (this.hasEyeTarget) {
      this.eyeTarget.classList.toggle("hidden", shouldShow)
    }
    if (this.hasEyeOffTarget) {
      this.eyeOffTarget.classList.toggle("hidden", !shouldShow)
    }
  }

  applyRole(role) {
    if (this.hasRoleInputTarget) {
      this.roleInputTarget.value = role
    }
    if (this.hasRoleStudentTarget) {
      this.toggleRoleButton(this.roleStudentTarget, role === "student")
    }
    if (this.hasRoleTeacherTarget) {
      this.toggleRoleButton(this.roleTeacherTarget, role === "teacher")
    }
  }

  toggleRoleButton(target, isActive) {
    const activeClasses = (target.dataset.activeClasses || "").split(" ").filter(Boolean)
    const inactiveClasses = (target.dataset.inactiveClasses || "").split(" ").filter(Boolean)

    if (isActive) {
      target.classList.add(...activeClasses)
      target.classList.remove(...inactiveClasses)
    } else {
      target.classList.add(...inactiveClasses)
      target.classList.remove(...activeClasses)
    }
  }
}

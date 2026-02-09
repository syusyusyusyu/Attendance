import { Application } from "@hotwired/stimulus"

const application = Application.start()
application.debug = false

const applyLoading = (submitter) => {
  if (!submitter || submitter.dataset.loadingApplied === "true") return

  const isInput = submitter.tagName === "INPUT"
  const originalText = isInput ? submitter.value : submitter.textContent
  submitter.dataset.loadingApplied = "true"
  submitter.dataset.loadingOriginal = originalText

  const loadingText = submitter.dataset.loadingText || "処理中..."
  if (isInput) {
    submitter.value = loadingText
  } else {
    submitter.textContent = loadingText
  }

  submitter.disabled = true
  submitter.setAttribute("aria-busy", "true")
  submitter.classList.add("is-loading")
}

const clearLoading = (submitter) => {
  if (!submitter || submitter.dataset.loadingApplied !== "true") return

  const originalText = submitter.dataset.loadingOriginal || ""
  if (submitter.tagName === "INPUT") {
    submitter.value = originalText
  } else {
    submitter.textContent = originalText
  }

  submitter.disabled = false
  submitter.removeAttribute("aria-busy")
  submitter.classList.remove("is-loading")
  delete submitter.dataset.loadingApplied
  delete submitter.dataset.loadingOriginal
}

const getSubmitter = (event) =>
  event.detail?.submitter || event.detail?.formSubmission?.submitter

document.addEventListener("turbo:submit-start", (event) => {
  applyLoading(getSubmitter(event))
})

document.addEventListener("turbo:submit-end", (event) => {
  clearLoading(getSubmitter(event))
})

document.addEventListener("submit", (event) => {
  applyLoading(event.submitter)
})

window.Stimulus = application

export { application }

import OpengraphEmbedOperation from "./lib/opengraph_embed_operation"
import Paste from "./lib/paste"

const performOperation = (function() {
  let operation = null
  let requestId = null

  return function(operationToPerform) {
    operation?.abort()
    cancelAnimationFrame(requestId)

    requestId = requestAnimationFrame(function() {
      operation = operationToPerform
      operation.perform().then(() => operation = null)
    })
  }
})()

export function installUnfurler() {
  addEventListener("trix-initialize", function(event) {
    if (editorElementPermitsAttribute(event.target, "href")) {
      event.target.addEventListener("trix-paste", didPaste)
    }
  })
}

function didPaste(event) {
  const { range } = event.paste
  const { editor } = event.target

  if (range != null) {
    const paste = new Paste(range, editor).getSignificantPaste()

    if (paste.isURL()) {
      if (editorElementPermitsOpengraphAttachment(event.target)) {
        performOperation(new OpengraphEmbedOperation(paste))
      }
    }
  }
}

function editorElementPermitsAttribute(element, attributeName) {
  if (element.hasAttribute("data-permitted-attributes")) {
    return Array.from(element.getAttribute("data-permitted-attributes").split(" ")).includes(attributeName)
  } else {
    return true
  }
}

function editorElementPermitsOpengraphAttachment(element) {
  const permittedAttachmentTypes = element.getAttribute("data-permitted-attachment-types")
  return permittedAttachmentTypes && permittedAttachmentTypes.includes("application/vnd.actiontext.opengraph-embed")
}

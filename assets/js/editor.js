export const PythonEditor = {
  mounted() {
    this.onKey = event => {
      if (event.key !== "Tab" || event.shiftKey || this.el.readOnly) return
      event.preventDefault()
      this.el.setRangeText("    ", this.el.selectionStart, this.el.selectionEnd, "end")
      this.el.dispatchEvent(new Event("input", {bubbles: true}))
    }
    this.el.addEventListener("keydown", this.onKey)
  },
  destroyed() { this.el.removeEventListener("keydown", this.onKey) },
}

import { Controller } from "@hotwired/stimulus"

// Lexxy ships its toolbar tooltips hard-coded in English inside the bundled
// JS (no i18n hook upstream). This controller intercepts the toolbar buttons
// as they appear in the DOM and rewrites the `title` attribute when the page
// is rendered in a translated locale.
//
// Mounted on <body data-controller="lexxy-i18n"> in application layout.

const TRANSLATIONS = {
  "zh-CN": {
    "Add images and video": "插入图片/视频",
    "Upload files": "上传附件",
    "Bold": "加粗",
    "Italic": "斜体",
    "Underline": "下划线",
    "Strikethrough": "删除线",
    "Text formatting": "文本格式",
    "Clear formatting": "清除格式",
    "Color highlight": "高亮颜色",
    "Link": "链接",
    "Quote": "引用",
    "Code": "代码块",
    "Bullet list": "无序列表",
    "Numbered list": "有序列表",
    "Insert a table": "插入表格",
    "Insert a divider": "插入分隔线",
    "Paragraph": "段落",
    "Small heading": "小标题",
    "Medium heading": "中标题",
    "Large heading": "大标题",
    "Plain text": "纯文本",
    "Undo": "撤销",
    "Redo": "重做",
    "More toolbar buttons": "更多工具",
    "Show more toolbar buttons": "显示更多工具",
    "Optional title": "可选标题",
    "Remove": "移除",
    "Nothing found": "未找到",
    "Files": "文件"
  }
}

export default class extends Controller {
  connect() {
    const locale = document.documentElement.lang
    this.dictionary = TRANSLATIONS[locale]
    if (!this.dictionary) return

    this.translateAll(this.element)

    this.observer = new MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.type === "childList") {
          m.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) this.translateAll(node)
          })
        } else if (m.type === "attributes" && m.attributeName === "title") {
          this.translate(m.target)
        }
      }
    })

    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: [ "title" ]
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  translateAll(root) {
    if (root.matches?.("[title]")) this.translate(root)
    root.querySelectorAll?.("[title]").forEach(el => this.translate(el))
  }

  translate(el) {
    const current = el.getAttribute("title")
    const next = this.dictionary[current]
    if (next && next !== current) {
      el.setAttribute("title", next)
      if (el.hasAttribute("aria-label")) el.setAttribute("aria-label", next)
    }
  }
}

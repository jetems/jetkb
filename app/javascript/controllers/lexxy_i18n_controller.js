import { Controller } from "@hotwired/stimulus"

// Lexxy ships its toolbar tooltips hard-coded in English inside the bundled
// JS (no i18n hook upstream). This controller intercepts the toolbar buttons
// as they appear in the DOM and rewrites the `title` attribute when the page
// is rendered in a translated locale.
//
// Mounted on <body data-controller="lexxy-i18n"> in application layout.

const TRANSLATIONS = {
  "zh-CN": {
    // title / aria-label / button text — exact-string lookup
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
    "Unlink": "取消链接",
    "Quote": "引用",
    "Code": "代码块",
    "Bullet list": "无序列表",
    "Numbered list": "有序列表",
    "Insert a table": "插入表格",
    "Insert a divider": "插入分隔线",
    "Paragraph": "段落",
    "Normal": "正文",
    "Small heading": "小标题",
    "Medium heading": "中标题",
    "Large heading": "大标题",
    "Small Heading": "小标题",
    "Medium Heading": "中标题",
    "Large Heading": "大标题",
    "Plain text": "纯文本",
    "Undo": "撤销",
    "Redo": "重做",
    "More toolbar buttons": "更多工具",
    "Show more toolbar buttons": "显示更多工具",
    "Optional title": "可选标题",
    "Remove": "移除",
    "Delete": "删除",
    "Delete this table?": "删除该表格?",
    "Nothing found": "未找到",
    "Files": "文件",
    // input placeholders
    "Enter a URL…": "输入链接地址…",
    "Enter a URL...": "输入链接地址…"
  }
}

// Dynamic patterns for strings like "3 rows" / "1 column" that Lexxy
// composes at runtime. Each entry is [regex, replacer(locale, match)].
const DYNAMIC_PATTERNS = [
  [ /^(\d+) rows?$/,    (_locale, m) => `${m[1]} 行` ],
  [ /^(\d+) columns?$/, (_locale, m) => `${m[1]} 列` ]
]

export default class extends Controller {
  connect() {
    this.locale = document.documentElement.lang
    this.dictionary = TRANSLATIONS[this.locale]
    if (!this.dictionary) return

    this.translateAll(this.element)

    this.observer = new MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.type === "childList") {
          m.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              this.translateAll(node)
            } else if (node.nodeType === Node.TEXT_NODE) {
              // textContent = "3 rows" replaces children with a fresh text
              // node — catch the new one so DYNAMIC_PATTERNS apply.
              this.translateText(node)
            }
          })
        } else if (m.type === "attributes") {
          const name = m.attributeName
          if (name === "title" || name === "aria-label" || name === "placeholder") {
            this.translateAttr(m.target, name)
          }
        } else if (m.type === "characterData") {
          this.translateText(m.target)
        }
      }
    })

    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: [ "title", "aria-label", "placeholder" ]
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  translateAll(root) {
    // Attributes
    for (const attr of [ "title", "aria-label", "placeholder" ]) {
      if (root.matches?.(`[${attr}]`)) this.translateAttr(root, attr)
      root.querySelectorAll?.(`[${attr}]`).forEach(el => this.translateAttr(el, attr))
    }
    // Inner text — only for Lexxy buttons (limit scope; we don't want to
    // touch arbitrary user text or framework labels)
    this.translateLexxyButtonsIn(root)
  }

  translateLexxyButtonsIn(root) {
    // Covers (a) flat toolbar buttons, (b) buttons inside dropdown menus
    // (Normal/H2/H3/H4/Strikethrough/Underline/Clear formatting — these
    // lack the toolbar-button class), and (c) table inline controls.
    // Lexxy uses <button>Text</button> and <button>${icon}<span>Text</span></button>
    // templates; translateButton walks descendants to handle both.
    const selector = [
      "button.lexxy-editor__toolbar-button",
      "button.lexxy-table-control__button",
      ".lexxy-editor__toolbar-dropdown-list button"
    ].join(", ")
    if (root.matches?.(selector)) this.translateButton(root)
    root.querySelectorAll?.(selector).forEach(el => this.translateButton(el))
  }

  translateAttr(el, name) {
    const current = el.getAttribute(name)
    if (!current) return
    const next = this.lookup(current)
    if (next && next !== current) el.setAttribute(name, next)
  }

  translateButton(el) {
    // Find the first text-bearing descendant whose trimmed value is in the
    // dictionary. This covers <button>Unlink</button>, <button>${icon}
    // <span>Delete this table?</span></button>, and similar.
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, {
      acceptNode: node => node.nodeValue.trim() ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT
    })
    let node
    while ((node = walker.nextNode())) {
      const trimmed = node.nodeValue.trim()
      const next = this.lookup(trimmed)
      if (next && next !== trimmed) {
        node.nodeValue = node.nodeValue.replace(trimmed, next)
        return
      }
    }
  }

  translateText(textNode) {
    const trimmed = textNode.nodeValue.trim()
    if (!trimmed) return
    const next = this.lookup(trimmed)
    if (next && next !== trimmed) textNode.nodeValue = textNode.nodeValue.replace(trimmed, next)
  }

  lookup(value) {
    const exact = this.dictionary[value]
    if (exact) return exact
    for (const [ regex, replacer ] of DYNAMIC_PATTERNS) {
      const match = value.match(regex)
      if (match) return replacer(this.locale, match)
    }
    return null
  }
}

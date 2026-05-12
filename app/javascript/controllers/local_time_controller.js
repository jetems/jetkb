import { Controller } from "@hotwired/stimulus"
import { differenceInDays, secondsToDate } from "helpers/date_helpers"

const DEFAULT_LOCALE = document.documentElement.lang || "en-US"

const I18N = {
  "zh-CN": {
    today: "今天",
    yesterday: "昨天",
    tomorrow: "明天",
    less_than_minute: "不到一分钟前",
    ago_template: (n, unit) => `${n}${unit}前`,
    in_template: (n, unit) => `${n}${unit}后`,
    days_ago_template: (n) => `${n} 天前`,
    units: { year: "年", month: "个月", week: "周", day: "天", hour: "小时", minute: "分钟" }
  },
  "en-US": {
    today: "today",
    yesterday: "yesterday",
    tomorrow: "tomorrow",
    less_than_minute: "Less than a minute ago",
    ago_template: (n, unit) => `${n} ${unit}${n === 1 ? "" : "s"} ago`,
    in_template: (n, unit) => `in ${n} ${unit}${n === 1 ? "" : "s"}`,
    days_ago_template: (n) => `${n} days ago`,
    units: { year: "year", month: "month", week: "week", day: "day", hour: "hour", minute: "minute" }
  }
}

function strings() {
  return I18N[DEFAULT_LOCALE] || I18N["en-US"]
}

export default class extends Controller {
  static targets = [ "time", "date", "datetime", "shortdate", "ago", "indays", "daysago", "agoorweekday", "timeordate" ]
  static values = { refreshInterval: Number }
  static classes = [ "local-time-value"]

  #timer

  initialize() {
    this.timeFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, { timeStyle: "short" })
    this.dateFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, { dateStyle: "long" })
    this.shortdateFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, { month: "short", day: "numeric" })
    this.datetimeFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, { timeStyle: "short", dateStyle: "short" })
    this.agoFormatter = new AgoFormatter()
    this.daysagoFormatter = new DaysAgoFormatter()
    this.datewithweekdayFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, { weekday: "long", month: "long", day: "numeric" })
    this.datewithweekdayFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, { weekday: "long", month: "long", day: "numeric" })
    this.indaysFormatter = new InDaysFormatter()
    this.agoorweekdayFormatter = new DaysAgoOrWeekdayFormatter()
    this.timeordateFormatter = new TimeOrDateFormatter()
  }

  connect() {
    this.#timer = setInterval(() => this.#refreshRelativeTimes(), 30_000)
  }

  disconnect() {
    clearInterval(this.#timer)
  }

  refreshAll() {
    this.constructor.targets.forEach(targetName => {
      this.targets.findAll(targetName).forEach(target => {
        this.#formatTime(this[`${targetName}Formatter`], target)
      })
    })
  }

  refreshTarget(event) {
    const target = event.target;
    const targetName = target.dataset.localTimeTarget
    this.#formatTime(this[`${targetName}Formatter`], target)
  }

  timeTargetConnected(target) {
    this.#formatTime(this.timeFormatter, target)
  }

  dateTargetConnected(target) {
    this.#formatTime(this.dateFormatter, target)
  }

  datetimeTargetConnected(target) {
    this.#formatTime(this.datetimeFormatter, target)
  }

  shortdateTargetConnected(target) {
    this.#formatTime(this.shortdateFormatter, target)
  }

  agoTargetConnected(target) {
    this.#formatTime(this.agoFormatter, target)
  }

  indaysTargetConnected(target) {
    this.#formatTime(this.indaysFormatter, target)
  }

  daysagoTargetConnected(target) {
    this.#formatTime(this.daysagoFormatter, target)
  }

  agoorweekdayTargetConnected(target) {
    this.#formatTime(this.agoorweekdayFormatter, target)
  }

  timeordateTargetConnected(target) {
    this.#formatTime(this.timeordateFormatter, target)
  }

  #refreshRelativeTimes() {
    this.agoTargets.forEach(target => {
      this.#formatTime(this.agoFormatter, target)
    })
  }

  #formatTime(formatter, target) {
    const dt = secondsToDate(parseInt(target.getAttribute("datetime")))
    target.innerHTML = formatter.format(dt)
    target.title = this.datetimeFormatter.format(dt)
  }
}

class AgoFormatter {
  format(dt) {
    const now = new Date()
    const seconds = (now - dt) / 1000
    const minutes = seconds / 60
    const hours = minutes / 60
    const days = hours / 24
    const weeks = days / 7
    const months = days / (365 / 12)
    const years = days / 365

    if (years >= 1) return this.#renderAgo("year", years)
    if (months >= 1) return this.#renderAgo("month", months)
    if (weeks >= 1) return this.#renderAgo("week", weeks)
    if (days >= 1) return this.#renderAgo("day", days)
    if (hours >= 1) return this.#renderAgo("hour", hours)
    if (minutes >= 1) return this.#renderAgo("minute", minutes)

    return strings().less_than_minute
  }

  #renderAgo(unit, quantity) {
    const s = strings()
    const n = Math.floor(quantity)
    return s.ago_template(n, s.units[unit])
  }
}

class DaysAgoFormatter {
  format(date) {
    const s = strings()
    const days = differenceInDays(date, new Date())

    if (days <= 0) return styleableValue(s.today)
    if (days === 1) return styleableValue(s.yesterday)
    return s.days_ago_template(styleableValue(days))
  }
}

class DaysAgoOrWeekdayFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())

    if (days <= 1) {
      return new DaysAgoFormatter().format(date)
    } else {
      return new Intl.DateTimeFormat(DEFAULT_LOCALE, { weekday: "long", month: "long", day: "numeric" }).format(date)
    }
  }
}

class InDaysFormatter {
  format(date) {
    const s = strings()
    const days = differenceInDays(new Date(), date)

    if (days <= 0) return styleableValue(s.today)
    if (days === 1) return styleableValue(s.tomorrow)
    return s.in_template(styleableValue(days), s.units.day)
  }
}

class TimeOrDateFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())

    if (days >= 1) {
      return new Intl.DateTimeFormat(DEFAULT_LOCALE, { month: "short", day: "numeric" }).format(date)
    } else {
      return new Intl.DateTimeFormat(DEFAULT_LOCALE, { timeStyle: "short" }).format(date)
    }
  }
}

function styleableValue(value) {
  return `<span class="local-time-value">${value}</span>`
}

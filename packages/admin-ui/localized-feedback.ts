import { t } from '../localization/language'

type Options = Record<string, unknown>

function options(value: Options): Options {
  const translated = { ...value }
  for (const key of ['message', 'title', 'confirmButtonText', 'cancelButtonText', 'inputPlaceholder', 'inputErrorMessage']) {
    if (key in translated) translated[key] = t(translated[key])
  }
  if (typeof value.inputValidator === 'function') {
    const validate = value.inputValidator
    translated.inputValidator = (...args: unknown[]) => t(validate(...args))
  }
  return translated
}

function messageArgs(args: unknown[]) {
  const [first, ...rest] = args
  return [first && typeof first === 'object' && 'message' in first ? options(first as Options) : t(first), ...rest]
}

/** Translate only UI options. Prompt values and callback arguments remain unchanged. */
export function localizedMessage<T extends object>(service: T): T {
  return new Proxy(service, {
    apply(target, receiver, args) { return Reflect.apply(target as Function, receiver, messageArgs(args)) },
    get(target, key, receiver) {
      const method = Reflect.get(target, key, receiver)
      if (['success', 'warning', 'info', 'error', 'primary'].includes(String(key)) && typeof method === 'function') {
        return (...args: unknown[]) => Reflect.apply(method, target, messageArgs(args))
      }
      return method
    },
  })
}

export function localizedMessageBox<T extends object>(service: T): T {
  return new Proxy(service, {
    apply(target, receiver, args) {
      const [first, ...rest] = args
      return Reflect.apply(target as Function, receiver, [first && typeof first === 'object' ? options(first as Options) : t(first), ...rest])
    },
    get(target, key, receiver) {
      const method = Reflect.get(target, key, receiver)
      if (['confirm', 'alert', 'prompt'].includes(String(key)) && typeof method === 'function') {
        return (message: unknown, title?: unknown, config?: Options, ...rest: unknown[]) => {
          const shorthand = title && typeof title === 'object'
          const supplied = (shorthand ? title : config) as Options | undefined
          const translated = options({ confirmButtonText: t('确定'), cancelButtonText: t('取消'), ...supplied })
          return Reflect.apply(method, target, [t(message), shorthand ? translated : t(title), ...(shorthand ? [] : [translated]), ...rest])
        }
      }
      return method
    },
  })
}

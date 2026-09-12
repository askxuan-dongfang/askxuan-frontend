import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

/** One keyboard/touch lifecycle for the three admin shells. */
export function useAdminNavigation(routePath: () => string) {
  const collapsed = ref(false)
  const mobile = ref(false)
  const drawerOpen = ref(false)
  const sidebarRef = ref<HTMLElement>()
  const toggleRef = ref<HTMLButtonElement>()
  let mobileQuery: MediaQueryList | undefined
  let previousOverflow: string | undefined
  let disposed = false

  function focusableItems() {
    return Array.from(sidebarRef.value?.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'
    ) || []).filter(item => !item.closest('[inert]') && item.getClientRects().length > 0)
  }

  function closeNavigation() { drawerOpen.value = false }
  function toggleNavigation() {
    if (mobile.value) drawerOpen.value = !drawerOpen.value
    else collapsed.value = !collapsed.value
  }
  function syncViewport(event?: MediaQueryListEvent) {
    mobile.value = event ? event.matches : Boolean(mobileQuery?.matches)
    if (!mobile.value) closeNavigation()
  }
  function restoreScroll() {
    if (previousOverflow === undefined) return
    document.documentElement.style.overflow = previousOverflow
    previousOverflow = undefined
  }
  function onKeydown(event: KeyboardEvent) {
    if (!drawerOpen.value || !sidebarRef.value?.contains(document.activeElement)) return
    if (event.key === 'Escape') {
      event.preventDefault()
      closeNavigation()
    } else if (event.key === 'Tab') {
      const items = focusableItems()
      const first = items[0]
      const last = items[items.length - 1]
      if (!first) {
        event.preventDefault()
        sidebarRef.value.focus()
      } else if (event.shiftKey && (document.activeElement === first || document.activeElement === sidebarRef.value)) {
        event.preventDefault()
        last?.focus()
      } else if (!event.shiftKey && (document.activeElement === last || document.activeElement === sidebarRef.value)) {
        event.preventDefault()
        first.focus()
      }
    }
  }

  watch(routePath, closeNavigation)
  watch(drawerOpen, async open => {
    if (open) {
      previousOverflow = document.documentElement.style.overflow
      document.documentElement.style.overflow = 'hidden'
      await nextTick()
      if (disposed || !drawerOpen.value) return
      const active = sidebarRef.value?.querySelector<HTMLElement>('.el-menu-item.is-active')
      if (active && active.getClientRects().length > 0) active.focus()
      else (focusableItems()[0] || sidebarRef.value)?.focus()
    } else {
      restoreScroll()
      await nextTick()
      if (!disposed && !drawerOpen.value) toggleRef.value?.focus({ preventScroll: true })
    }
  }, { flush: 'post' })

  onMounted(() => {
    mobileQuery = window.matchMedia('(max-width: 991px)')
    syncViewport()
    mobileQuery.addEventListener('change', syncViewport)
    document.addEventListener('keydown', onKeydown)
  })
  onBeforeUnmount(() => {
    disposed = true
    restoreScroll()
    mobileQuery?.removeEventListener('change', syncViewport)
    document.removeEventListener('keydown', onKeydown)
  })

  return { collapsed, mobile, drawerOpen, sidebarRef, toggleRef, toggleNavigation, closeNavigation }
}

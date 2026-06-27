import type { MaybeRefOrGetter } from 'vue'

// Sets the page title + description and mirrors them to Open Graph and Twitter
// card tags in one call. Global og defaults (site name, type, image, card type)
// live in app.vue.
export function usePageSeo(meta: {
  title: MaybeRefOrGetter<string>
  description?: MaybeRefOrGetter<string | undefined>
}) {
  const title = () => toValue(meta.title)
  const description = () => toValue(meta.description)

  useSeoMeta({
    title,
    ogTitle: title,
    twitterTitle: title,
    description,
    ogDescription: description,
    twitterDescription: description,
  })
}

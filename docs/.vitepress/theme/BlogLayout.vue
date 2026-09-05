<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue"
import { Content, useRoute, withBase } from "vitepress"
import type { Post } from "../blog.mts"
import { bannerUrl, formatDate } from "./blog"
import { useFlash } from "./composables"
import { ICONS } from "./icons"
import OutlineTree from "./OutlineTree.vue"
import { useTheme } from "./types"

const { theme, page, frontmatter } = useTheme()
const route = useRoute()
const posts = computed(() => theme.value.blog ?? [])
const index = computed(() => posts.value.findIndex((p) => `blog/${p.slug}.md` === page.value.relativePath))
const post = computed(() => posts.value[index.value])
const newer = computed(() => posts.value[index.value - 1])
const older = computed(() => posts.value[index.value + 1])
const link = (p: Post) => withBase(`/blog/${p.slug}`)
const tagLink = (tag: string) => withBase(`/blog/?tag=${encodeURIComponent(tag)}`)

const tag = ref<string>()
const tags = computed(() => {
	const counts = new Map<string, number>()
	for (const p of posts.value) for (const t of p.tags) counts.set(t, (counts.get(t) ?? 0) + 1)
	return [...counts]
})
const shown = computed(() => (tag.value ? posts.value.filter((p) => p.tags.includes(tag.value!)) : posts.value))

function pickTag(next?: string) {
	tag.value = next
	const url = new URL(location.href)
	if (next) url.searchParams.set("tag", next)
	else url.searchParams.delete("tag")
	history.replaceState(history.state, "", url)
}

const { message: shared, flash } = useFlash(1600)

function readTag() {
	tag.value = new URLSearchParams(location.search).get("tag") ?? undefined
}

async function share() {
	const url = location.href.split("#")[0]
	if (navigator.share) {
		try {
			await navigator.share({ title: post.value?.title, url })
		} catch (error) {
			if (!(error instanceof DOMException && error.name === "AbortError")) flash("Sharing failed")
		}
		return
	}
	try {
		await navigator.clipboard.writeText(url)
		flash("Link copied")
	} catch {
		flash("Copy failed")
	}
}

onMounted(readTag)
watch(() => route.path, readTag)
</script>

<template>
	<div class="fd-blog">
		<template v-if="post">
			<article class="fd-post">
				<a class="fd-blog-back" :href="withBase('/blog/')">
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6" /></svg>
					All posts
				</a>
				<header class="fd-post-title">
					<h1>{{ post.title }}</h1>
					<p>{{ post.description }}</p>
					<div class="fd-post-byline">
						<img :src="post.avatar" alt="" width="40" height="40" />
						<div>
							<span class="fd-post-who"><strong>{{ post.author }}</strong> · {{ post.role }}</span>
							<span class="fd-post-when">
								<time :datetime="post.date">{{ formatDate(post.date) }}</time>
								<span aria-hidden="true">·</span>
								{{ post.minutes }} min read
								<a v-for="t in post.tags" :key="t" class="fd-post-tag" :href="tagLink(t)">{{ t }}</a>
							</span>
						</div>
					</div>
				</header>
				<template v-if="bannerUrl(post.banner)">
					<img class="fd-post-banner" :class="{ 'fd-only-light': bannerUrl(post.banner, true) }" :src="bannerUrl(post.banner)" alt="" />
					<img v-if="bannerUrl(post.banner, true)" class="fd-post-banner fd-only-dark" :src="bannerUrl(post.banner, true)" alt="" />
				</template>
				<div class="fd-post-main">
					<Content class="vp-doc fd-blog-body" />
					<aside class="fd-post-rail">
						<OutlineTree class="fd-post-outline" />
						<button type="button" class="fd-post-share" @click="share">
							<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 15V3M8 7l4-4 4 4M5 13v7h14v-7" /></svg>
							<span aria-live="polite">{{ shared || "Share this post" }}</span>
						</button>
					</aside>
				</div>
				<nav class="fd-blog-pager" aria-label="More posts">
					<a v-if="older" :href="link(older)"><small>Older</small>{{ older.title }}</a>
					<a v-else :href="withBase('/blog/')"><small>Blog</small>All posts</a>
					<a v-if="newer" class="fd-blog-pager-next" :href="link(newer)"><small>Newer</small>{{ newer.title }}</a>
				</nav>
			</article>
		</template>

		<template v-else>
			<header class="fd-blog-intro">
				<div>
					<h1>{{ frontmatter.title }}</h1>
					<p>Announcements and release notes from Rivue.</p>
				</div>
				<div class="fd-blog-filters" role="group" aria-label="Filter by tag">
					<button type="button" :aria-pressed="!tag" @click="pickTag()">All <span>{{ posts.length }}</span></button>
					<button v-for="[t, count] in tags" :key="t" type="button" :aria-pressed="tag === t" @click="pickTag(t)">
						{{ t }} <span>{{ count }}</span>
					</button>
					<a class="fd-blog-rss" href="https://linhisreal.github.io/Rivue/feed.xml">
						<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 11a8 8 0 0 1 8 8M5 5a14 14 0 0 1 14 14" /><circle cx="6" cy="18" r="1.5" /></svg>
						RSS
					</a>
				</div>
			</header>

			<ol class="fd-timeline">
				<li v-for="(p, i) in shown" :key="p.slug" :class="{ latest: i === 0 }">
					<time class="fd-timeline-date" :datetime="p.date">{{ formatDate(p.date, "short") }}</time>
					<a class="fd-timeline-card" :href="link(p)">
						<template v-if="i === 0 && bannerUrl(p.banner)">
							<img :class="{ 'fd-only-light': bannerUrl(p.banner, true) }" :src="bannerUrl(p.banner)" alt="" />
							<img v-if="bannerUrl(p.banner, true)" class="fd-only-dark" :src="bannerUrl(p.banner, true)" alt="" />
						</template>
						<span class="fd-timeline-tags">
							<span v-if="i === 0 && !tag" class="fd-timeline-new">Latest</span>
							<span v-for="t in p.tags" :key="t">{{ t }}</span>
						</span>
						<strong>{{ p.title }}</strong>
						<span class="fd-timeline-text">{{ p.description }}</span>
						<span class="fd-timeline-more">
							Read the post
							<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="ICONS.arrow" /></svg>
						</span>
					</a>
				</li>
			</ol>
			<p v-if="!shown.length" class="fd-blog-empty">No posts with that tag yet.</p>
		</template>
	</div>
</template>

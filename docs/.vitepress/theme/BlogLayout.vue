<script setup lang="ts">
import { computed } from "vue"
import { Content, useData, withBase } from "vitepress"
import { bannerUrl, formatDate } from "./blog"

type Post = { slug: string; title: string; description: string; date: string; author: string; avatar: string; tags: string[]; banner?: string; minutes: number }

const { theme, page, frontmatter } = useData()
const posts = computed<Post[]>(() => theme.value.blog ?? [])
const index = computed(() => posts.value.findIndex((p) => `blog/${p.slug}.md` === page.value.relativePath))
const post = computed(() => posts.value[index.value])
const newer = computed(() => posts.value[index.value - 1])
const older = computed(() => posts.value[index.value + 1])
const link = (p: Post) => withBase(`/blog/${p.slug}`)
</script>

<template>
	<div class="fd-blog">
		<template v-if="post">
			<article class="fd-blog-post">
				<header class="fd-blog-head">
					<a class="fd-blog-back" :href="withBase('/blog/')">
						<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6" /></svg>
						Blog
					</a>
					<div class="fd-blog-tags">
						<span v-for="tag in post.tags" :key="tag">{{ tag }}</span>
					</div>
					<h1>{{ post.title }}</h1>
					<p class="fd-blog-lead">{{ post.description }}</p>
					<div class="fd-blog-byline">
						<img :src="post.avatar" alt="" width="28" height="28" />
						<span class="fd-blog-author">{{ post.author }}</span>
						<span aria-hidden="true">·</span>
						<time :datetime="post.date">{{ formatDate(post.date) }}</time>
						<span aria-hidden="true">·</span>
						<span>{{ post.minutes }} min read</span>
					</div>
				</header>
				<img v-if="bannerUrl(post.banner)" class="fd-blog-banner" :src="bannerUrl(post.banner)" :alt="post.title" />
				<Content class="vp-doc fd-blog-body" />
				<nav class="fd-blog-pager" aria-label="More posts">
					<a v-if="older" :href="link(older)"><small>Older</small>{{ older.title }}</a>
					<a v-else :href="withBase('/blog/')"><small>Blog</small>All posts</a>
					<a v-if="newer" class="fd-blog-pager-next" :href="link(newer)"><small>Newer</small>{{ newer.title }}</a>
				</nav>
			</article>
		</template>

		<template v-else>
			<header class="fd-blog-intro">
				<h1>{{ frontmatter.title }}</h1>
				<p>Releases, changes, and why they were made.</p>
				<a class="fd-blog-rss" href="https://linhisreal.github.io/Rivue/feed.xml">
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 11a8 8 0 0 1 8 8M5 5a14 14 0 0 1 14 14" /><circle cx="6" cy="18" r="1.5" /></svg>
					RSS feed
				</a>
			</header>
			<ul class="fd-blog-list">
				<li v-for="(p, i) in posts" :key="p.slug" :class="{ featured: i === 0 }">
					<a :href="link(p)">
						<img v-if="bannerUrl(p.banner)" :src="bannerUrl(p.banner)" alt="" :loading="i === 0 ? 'eager' : 'lazy'" />
						<span class="fd-blog-card">
							<span class="fd-blog-card-meta">
								<time :datetime="p.date">{{ formatDate(p.date) }}</time>
								<span v-for="tag in p.tags" :key="tag" class="fd-blog-tag">{{ tag }}</span>
							</span>
							<strong>{{ p.title }}</strong>
							<span class="fd-blog-card-text">{{ p.description }}</span>
						</span>
					</a>
				</li>
			</ul>
		</template>
	</div>
</template>

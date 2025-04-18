[Docs](../README.md) › [Guide](../GUIDE.md) › **9. Performance and debugging**

# 9. Performance, debugging and common mistakes

Most of the time you won't think about performance. This chapter is for when you do: the few
things that make a Rivue UI slow, how to find out why something rendered, and the mistakes almost
everyone makes once.

## Performance

Rivue is fast by default. When it isn't, it's usually one of these:

| Situation | Do this |
|---|---|
| A list changes often | give every item a `key` ([chapter 3](03-describing-ui.md#lists-and-keys)) |
| One big screen re-renders on every change | split it into components: only those that read the changed state re-render |
| Hundreds of rows | `Rivue.VirtualList` creates only the rows on screen |
| Rows that rarely change | `memo = { item.id, item.version }` skips patching while those stay the same |
| Big data you replace rather than edit | `Rivue.shallowRef` doesn't make the contents reactive |
| Lots of short-lived Instances | `createApp(App, { usePool = true })` reuses them |

## Debugging

Start in the Explorer. Each component's root Instance is named after the component, so the tree
there already reads like your component tree.

For more detail, `app:printTree()` prints the components with their props and what they rendered:

```
<TodoList>
  Frame "TodoList"
    TextBox "Input"
    <TodoItem todo=table>
      Frame "TodoItem"
```

If something re-renders and you can't see why, add
`Rivue.onRenderTriggered(function(e) print(e.key) end)` to its setup. It prints the key that
changed.

Errors tell you where they came from, like
`[Rivue] Error in render of <ItemRow> in <Inventory> in <App>`, and errors in watchers and effects
are always reported. In Studio you also get warnings for unknown properties, wrong prop types,
duplicate keys, list items without keys and undeclared events. And when `print` shows a reactive
table as empty, `Rivue.inspect(value)` shows what's actually in it.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| UI doesn't update | the value was read in `setup`, not in render | read it inside `render` ([chapter 2](02-state.md#reads-during-render-are-tracked)) |
| UI doesn't update after `table.insert(list, x)` | `table.*` bypasses reactive proxies | `Rivue.array.push(list, x)` |
| `pairs`/`ipairs` over reactive state finds nothing | Luau has no `__pairs` | `for k, v in state do` or `for i = 1, #list do` |
| `model = ctx.draft` doesn't bind | `ctx` unwraps refs, so it passes the string | `model = "draft"` |
| A copied prop never changes | `local name = props.name` copies the value | read `props.name` in render, or `Rivue.toRef(props, "name")` |
| `onMounted must be called inside a component's setup()` | hook called in render or later | call hooks at the top of `setup` |
| Every row re-renders on each change | missing `key` | give every list item a stable key |
| Child state resets when the parent re-renders | the child's type or `key` changes between renders | keep the same component and key for the same item |
| Type errors on children lists in `--!strict` | the old type solver can't infer mixed lists | use `--!nonstrict` for UI files, or the new solver |

---

**Reference:** [VirtualList](../api/builtins.md#virtuallist) · [printTree()](../api/utilities.md#printtree) ·
[onRenderTriggered()](../api/lifecycle.md#onrendertriggered) · [Pooling options](../api/application.md#pooling-options)

[← 8. Sharing state and the server](08-state-and-server.md) · [Guide contents](../GUIDE.md) · [10. Organising a project →](10-organising-a-project.md)

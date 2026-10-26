[Docs](../README.md) › [Guide](../GUIDE.md) › **9. Performance and debugging**

# 9. Performance, debugging and common mistakes

**You'll learn:** the few things that make Rivue UI slow, how to find out why something rendered,
and the mistakes almost everyone makes once.

## Performance

Rivue is fast by default. These cover the cases where it isn't:

| Situation | Do this |
|---|---|
| A list changes often | give every item a `key` ([chapter 3](03-describing-ui.md#lists-and-keys)) |
| One big screen re-renders on every change | split it into components: only those that read the changed state re-render |
| Hundreds of rows | `Rivue.VirtualList` creates only the rows on screen |
| Rows that rarely change | `memo = { item.id, item.version }` skips patching while those stay the same |
| Big data you replace rather than edit | `Rivue.shallowRef` doesn't make the contents reactive |
| Lots of short-lived Instances | `createApp(App, { usePool = true })` reuses them |

## Debugging

- **Look in the Explorer.** Each component's root Instance is named after the component, so the
  Explorer reads like your component tree.
- **Print the tree.** `app:printTree()` prints components with their props and what they rendered:

  ```
  <TodoList>
    Frame "TodoList"
      TextBox "Input"
      <TodoItem todo=table>
        Frame "TodoItem"
  ```

- **"Why did this re-render?"** Add `Rivue.onRenderTriggered(function(e) print(e.key) end)` to
  the component's setup.
- **Errors name the component chain:** `[Rivue] Error in render of <ItemRow> in <Inventory> in <App>`.
  Errors in watchers and effects are always reported.
- **Studio warnings** cover unknown properties, wrong prop types, duplicate keys, list items
  without keys and undeclared events.
- `Rivue.inspect(value)` prints reactive state readably.

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

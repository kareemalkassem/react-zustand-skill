/* __Entities__.module.css
   Tokens only. A literal color, radius, or shadow here is a bug —
   add the token to styles/variables.css instead. */

.page {
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
}

.empty {
  padding: var(--space-12) var(--space-6);
  text-align: center;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  background: var(--color-surface);
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-card);
}

.confirmText {
  margin: 0 0 var(--space-4);
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
  line-height: var(--leading-normal);
}

.rowActions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--space-2);
}

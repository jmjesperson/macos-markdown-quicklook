# Diagrams

First, a valid flowchart:

```mermaid
flowchart LR
  A[Start] --> B{Choose}
  B -->|yes| C[Ship it]
  B -->|no| D[Fix it]
```

Then an invalid one, broken on purpose. **Expected:** a red "Unable to render diagram" message, with the source shown below it, and the diagrams before and after still drawn:

```mermaid
flowchart LR
  A --> -->
  this is not mermaid
```

Text between the second and third diagram still renders.

```mermaid
sequenceDiagram
  Alice->>Bob: Hello Bob
  Bob-->>Alice: Hi Alice
```

Text after all diagrams.

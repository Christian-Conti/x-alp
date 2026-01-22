## Summary

| Name                                                     | Offset   |   Length | Description            |
|:---------------------------------------------------------|:---------|---------:|:-----------------------|
| fast_intr_ctrl.[`FAST_INTR_PENDING`](#fast_intr_pending) | 0x0      |        4 | Pending fast interrupt |
| fast_intr_ctrl.[`FAST_INTR_CLEAR`](#fast_intr_clear)     | 0x4      |        4 | Clear fast interrupt   |
| fast_intr_ctrl.[`FAST_INTR_ENABLE`](#fast_intr_enable)   | 0x8      |        4 | Enable fast interrupt  |

## FAST_INTR_PENDING
Pending fast interrupt
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "FAST_INTR_PENDING", "bits": 16, "attr": ["ro"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name              | Description                |
|:------:|:------:|:-------:|:------------------|:---------------------------|
| 31:16  |        |         |                   | Reserved                   |
|  15:0  |   ro   |   0x0   | FAST_INTR_PENDING | Pending Fast Interrupt Reg |

## FAST_INTR_CLEAR
Clear fast interrupt
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "FAST_INTR_CLEAR", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name            | Description          |
|:------:|:------:|:-------:|:----------------|:---------------------|
| 31:16  |        |         |                 | Reserved             |
|  15:0  |   rw   |   0x0   | FAST_INTR_CLEAR | Clear Fast Interrupt |

## FAST_INTR_ENABLE
Enable fast interrupt
- Offset: `0x8`
- Reset default: `0x7fff`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "FAST_INTR_ENABLE", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name             | Description           |
|:------:|:------:|:-------:|:-----------------|:----------------------|
| 31:16  |        |         |                  | Reserved              |
|  15:0  |   rw   | 0x7fff  | FAST_INTR_ENABLE | Enable fast interrupt |


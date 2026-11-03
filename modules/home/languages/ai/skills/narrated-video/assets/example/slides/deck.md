---
marp: true
theme: night
size: 1080p
paginate: false
html: true
---

<!-- _class: title -->

<div class="glyph">?</div>

# Schrödinger's Cache

<p class="subtitle">Eventually consistent. Probably.</p>

<p class="footer">Jeff Utter - Platform Guild, Lightning Talk</p>

---

<!-- _class: bullets -->

# The problem with caches

1. Every lookup must decide: hit or miss.
2. Deciding is expensive.
3. What if we just... didn't decide?

---

# Should you use it?

<div class="cols">
<div class="col good">

## Great for

- Benchmarks nobody reads
- Demos with the monitor off
- Staging

</div>
<div class="col bad">

## Terrible for

- Production <small>(someone is always watching)</small>
- Dashboards
- Your on-call rotation

</div>
</div>

---

<!-- _class: title -->

# Questions?

<p class="subtitle">They will collapse into answers once observed.</p>

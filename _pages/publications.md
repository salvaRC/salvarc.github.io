---
layout: page
permalink: /publications/
title: publications
description: "* denotes equal contribution. Also on <a href='https://scholar.google.com/citations?user=8RHc4eQAAAAJ'>Google Scholar</a>."
nav: true
nav_order: 1
pub_categories:
  - key: conference
    title: Conference & Journal Papers
  - key: preprint
    title: Preprints
  - key: workshop
    title: Workshop Papers & Conference Abstracts
---
<!-- _pages/publications.md -->
<div class="publications">

{%- for c in page.pub_categories %}
  <h2 class="pub-category">{{ c.title }}</h2>
  {% bibliography -f papers -q @*[category={{ c.key }}]* %}
{% endfor %}

</div>

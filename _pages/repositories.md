---
layout: page
permalink: /repositories/
title: repositories
description: Most of my research has code open-sourced on GitHub.
nav: true
nav_order: 3
---

## GitHub Repositories

{% if site.data.repositories.github_repos %}
<div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">
  {% for repo in site.data.repositories.github_repos %}
    {% include repository/repo.html repository=repo %}
  {% endfor %}
</div>
{% endif %}

[//]: # (## GitHub Account)

[//]: # ()
[//]: # ()
[//]: # ({% if site.data.repositories.github_users %})

[//]: # ()
[//]: # (<div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">)

[//]: # ()
[//]: # (  {% for user in site.data.repositories.github_users %})

[//]: # ()
[//]: # (    {% include repository/repo_user.html username=user %})

[//]: # ()
[//]: # (  {% endfor %})

[//]: # ()
[//]: # (</div>)

[//]: # ()
[//]: # ({% endif %})


---

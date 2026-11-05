<script>document.body.innerHTML='pwned'</script>

<img src="x" onerror="alert(1)">

[click](javascript:alert(1)) <a href="JaVaScRiPt:alert(1)">mixed case</a> <a href="jav&#x61;script:alert(1)">entity</a> <a href=" javascript:alert(1)">leading space</a> <a href="java	script:alert(1)">tab</a>

<iframe src="https://example.com"></iframe>

<p style="color:red" onclick="alert(1)" class="evil">styled</p>

<svg onload="alert(1)"><circle r="5"/></svg>

<form action="https://example.com"><input type="text" name="q"><button>go</button></form>

<a href="data:text/html,<script>alert(1)</script>">data link</a> <img src="data:image/png;base64,AAAA" alt="data image">

<object data="x.swf"></object><embed src="x.swf"><style>body{display:none}</style><meta http-equiv="refresh" content="0">

Text after the dropped elements still renders.

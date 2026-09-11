# Large-file follow-up

`main.py` is roughly 43 MB because several mojibake string literals occupy
millions of characters on individual lines. A safe follow-up should first add
route-level regression tests, then move routers, services, models and
repositories into modules and replace corrupted literals from a verified Thai
source. Do not perform a blind encoding conversion.

`mobile_app/assets/delivery/delivery_success.gif` is retained until a visually
equivalent optimized asset has been reviewed, so the delivery UX is not broken.

"""Cross-cutting API tests for FC ARENA.

App-specific behaviour lives in each app's ``tests.py``; this package covers the
endpoints that span apps (service root, health probe) and the end-to-end flows
that touch several apps at once.
"""

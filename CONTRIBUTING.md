# Contributing to the 0.1 Alpha

This is a bare-bones first release. Useful feedback matters more than the number of features.

If you would use CircuitDraft, star the repository or open a feature request with the real schematic task you want to complete. Small example projects and screenshots help explain the workflow. Share only files you can make public.

For bugs, include your macOS version, Mac architecture, the steps that trigger the issue, and what you expected. Use a small original example where possible.

For code contributions:

1. Open an issue to discuss substantial changes before building them.
2. Keep native app functionality independent of Python and Windows EPLAN.
3. Run `./test.sh` and `./test-automation.sh` on an Apple silicon Mac.
4. For MCP changes, run `Integrations/.venv/bin/python Integrations/test_mcp.py` after setting up its Python environment.
5. Preserve the upstream integration's MIT notice and pin; describe any intentional upstream changes.

No proprietary EPLAN files or commercial symbol libraries belong in the repository. Original code, original examples and properly licensed contributions are welcome. Contributions are provided under the repository's MIT license.

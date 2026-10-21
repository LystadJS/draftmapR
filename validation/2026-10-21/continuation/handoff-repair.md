# Handoff repair

The first Windows handoff exited with a call-depth overflow. PowerShell resolves command names without case sensitivity, so the Docker and Git helper functions recursively invoked themselves. They now invoke docker.exe and git.exe explicitly.

Validation: parsed the repaired script without syntax errors, loaded its actual helper definitions, successfully queried repository HEAD, confirmed the collection container is running, and read its execution-process JSON through the repaired helper. The original partial validator remains alive under supervisor token 20ea5216bdfb49cb8458ec1a0e8854fd. Its log is still at the original input catalog verification stage. Read counters increased between inspections; no partial success receipt or new collection launch is claimed.

The retained controller-error.txt records the historical failed handoff. Restarting the handoff does not restart the validator, regenerate fitted results, or weaken any validation gate. Limits remain 12 GiB memory, two CPUs, a 3 GiB host disk floor and a 3 GiB pinned-memory reserve.

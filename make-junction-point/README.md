.\\make-junction-point.ps1 -h
Alternatively:

PowerShell
.\\make-junction-point.ps1 -Help
Error Handling
The script encapsulates the execution logic inside a strict try-catch block. It explicitly checks for:

Target Absence: Throws an error if the specified TargetPath does not exist or is not a directory.

Path Collision: Prevents data corruption or accidental overwrites if JunctionPath is already used by an existing file or directory.

Clean Code Standards Applied
No Hardcoded Values: Fully parameterized variables ensure the script remains reusable across different automation workflows and environments.

Strict Validation: Employs explicit -PathType Container validation.

Silent Pipeline Pollution Prevention: Pipes output to Out-Null during successful item creation to maintain clean standard output.

Author & Version Information
Author: Roman Pindela

Email: roman.pindela@gmail.com

GitHub: github.com/romanpindela

Script Version: 1.0.0

Release Date: June 2026

License: MIT License. Feel free to use, modify, and distribute in enterprise environments.
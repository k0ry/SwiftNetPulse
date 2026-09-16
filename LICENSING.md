# Preparing SwiftNetPulse licensing

**Language:** [English](LICENSING.md) · [Русский](docs/ru/LICENSING.md)

Status on 16 September 2026: documents are prepared as drafts.
Confirmed model: free use solely for noncommercial purposes; commercial use
only under a separate paid license.

English is proposed as the controlling legal text, with Russian informational
translations in `docs/ru/`. The rightsholder must adopt that relationship when
finalizing; this file does not make the drafts effective.

## What was checked

The working tree had no licenses or copyright notices before this preparation.
The available local history has one commit `4db5430 Initial commit`; its author
is recorded as Filipp. Git metadata does not confirm a legal rightsholder,
completeness of rights in the sources, or consent to use the author's contact
for sales. External origin of the code and history of other copies were not
checked. `Package.swift` has no third-party package dependencies.

## Set of documents

- `LICENSE`: status and the scheme of two alternative licensing options.
  Russian informational translation: `docs/ru/LICENSE.md`.
- `LICENSE-NONCOMMERCIAL.md`: standalone draft of a free restricted license,
  including modification and distribution. Translation:
  `docs/ru/LICENSE-NONCOMMERCIAL.md`.
- `COMMERCIAL-LICENSE.md`: fill-in draft of paid-agreement terms. Translation:
  `docs/ru/COMMERCIAL-LICENSE.md`.
- README: short description of the model and links to the documents.

Some details of the free license are proposals for review: the definition of
commercial purpose, distribution rules, termination on breach, and the absence
of a separate patent grant. The user confirmed the licensing model but did not
separately agree those legal details.

## Required before release

1. State the full name of the rightsholder, copyright years, and confirm rights
   in all licensed code and the ability to dual-license.
2. State a confirmed contact for purchasing a commercial license.
3. Choose versions, effective date, and governing law; have the text reviewed
   by a lawyer of the relevant jurisdiction, including the definition of
   commercial use.
4. For the commercial agreement, settle the parties, price, payment, term,
   territory, modes of use, distribution, and the other marked terms.
5. Adopt the final texts and consistently remove draft status from LICENSE,
   both licenses, and the README. Confirm that no unfilled fields remain.

Existing licenses on previously released copies, if any are found, cannot be
treated as revoked merely because of a new text in this repository.
Changes have not been published or pushed to a remote repository.

## Sources and limits of the review

Cross-check against primary sources was done on 16 September 2026. The texts
above are original drafts, not MIT, Creative Commons, or OSI-approved licenses.

- [Open Source Initiative, Open Source Definition, section 6](https://opensource.org/osd):
  open source does not allow restricting field of endeavour, including business.
  A model that forbids free commercial use is therefore not called open source.
- [WIPO, Copyright FAQ](https://www.wipo.int/en/web/copyright/faq-copyright):
  permission to use is granted by the rights holder; licensing may be for a fee
  or free of charge. This is a reason to verify the identity and authority of
  the rightsholder, not proof of rights of a particular Git author.
- [Creative Commons, FAQ](https://creativecommons.org/faq/): CC does not
  recommend its licenses for software. CC BY-NC is therefore not used here.

These sources support general principles but do not certify legal effect of a
particular draft agreement in an unknown jurisdiction. A specialist must review
the final text after the fields are filled in.

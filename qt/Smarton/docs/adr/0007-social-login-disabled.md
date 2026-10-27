# 7. Provider sign-in buttons are rendered but disabled

Status: Accepted

## Context

The Login frame (`design/screens/03-login.png`) shows three provider buttons:
Google, Facebook, Apple. SmarTon authenticates against local accounts in a
SQLite file on the panel. There is no OAuth client registration, no redirect
URI, no token store, and — on an appliance that may run with no route to the
internet — no guarantee an identity provider is even reachable.

Three ways to handle the gap.

**Delete the buttons.** The implementation stops matching the design, and the
next person to compare the two assumes the screen is unfinished rather than
scoped.

**Wire them to something.** A button that opens a browser to an unregistered
OAuth client, or that quietly signs the user in locally, is a button that lies
about what it does. On a login screen that is not a cosmetic problem.

**Render them exactly as designed, disabled.** The design intent stays visible,
and the affordance tells the truth about what is available today.

## Decision

`StSocialButton` hard-sets `enabled: false` and `focusPolicy: Qt.NoFocus`. It
is not a property a screen can flip: enabling one is a code change in the
control, which is where the review question "and what is behind it?" belongs.

The buttons appear in the component gallery in that state, so a designer
reviewing the gallery against the Figma sees the difference immediately rather
than discovering it in the running app.

The same reasoning applies to "Sign up for free". Accounts are provisioned by
`smarton --create-account <name>`, or unattended from
`SMARTON_BOOTSTRAP_PASSWORD` on first boot (see `app/main.cpp`), so there is no
self-service registration to route to; the link goes to the recovery flow
rather than to a form that cannot succeed.

## Consequences

+ The screen matches the design, and nothing on it claims a capability the
  product does not have.
+ Adding a real provider is a self-contained change: remove the hard-set
  `enabled`, add the OAuth client behind it, supersede this ADR.
− Three visibly disabled controls sit on the primary login screen. That is a
  worse first impression than a screen without them, and it is the honest one.

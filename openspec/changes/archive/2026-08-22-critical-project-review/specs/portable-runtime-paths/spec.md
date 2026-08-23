# Portable Runtime Paths Specification

## Purpose

Define installation-independent runtime, helper, QML, wallpaper paths.

## Requirements

### Requirement: Context-derived paths

The system MUST resolve paths from the active installation, and MUST NOT depend on `/home/reaan/reaan-dotfiles` or another user-specific absolute path.

#### Scenario: Relocated checkout and temporary HOME

- GIVEN the checkout is relocated and `HOME` points to a temporary fixture
- WHEN a helper, QML boundary, or test resolves a path
- THEN it uses active checkout/configuration/runtime roots
- AND it does not read the historical path

#### Scenario: Existing valid operation

- GIVEN a supported layout and valid inputs
- WHEN a wallpaper, helper, or configuration operation runs
- THEN it preserves the existing result while using resolved paths

### Requirement: Confined wallpaper inputs

The system MUST accept wallpaper files only from the approved root and MUST reject absolute paths, traversal, and resolved paths outside it.

#### Scenario: Traversal or outside path

- GIVEN a wallpaper input contains `..`, an absolute path, or a symlink-resolved target outside the approved root
- WHEN the input is listed, copied, or applied
- THEN the operation fails closed without reading or applying the outside file

"""Rules for generating license reports using rules_license."""

load("@rules_license//rules:providers.bzl", "LicenseInfo")

LicenseReportInfo = provider(
    doc = "Provider for collecting transitive license information.",
    fields = {"entries": "depset of structs(target=str, licenses=tuple)"},
)

def _serialize_kind(kind):
    # LicenseKindInfo fields might vary, let's be safe
    return struct(
        name = kind.name,
        conditions = tuple(kind.conditions) if hasattr(kind, "conditions") else (),
    )

def _serialize_license(lic):
    # We use structs because they are hashable and can be put in depsets/tuples if needed recursively
    # But here we just need to ensure the top level list is a tuple

    kinds = tuple([_serialize_kind(k) for k in lic.license_kinds])

    return struct(
        kinds = kinds,
        copyright_notice = lic.copyright_notice,
        package_name = lic.package_name,
        license_text = lic.license_text.path if lic.license_text else None,
    )

def _license_aspect_impl(target, ctx):
    my_licenses = []

    # Check for applicable_licenses AND package_metadata
    candidates = []
    if hasattr(ctx.rule.attr, "applicable_licenses"):
        candidates.extend(ctx.rule.attr.applicable_licenses)
    if hasattr(ctx.rule.attr, "package_metadata"):
        candidates.extend(ctx.rule.attr.package_metadata)

    for dep in candidates:
        if LicenseInfo in dep:
            my_licenses.append(dep[LicenseInfo])

    serialized_licenses = tuple([_serialize_license(lic) for lic in my_licenses])

    entry = struct(
        target = str(target.label),
        target_licenses = serialized_licenses,
    )

    transitive_entries = []

    attr_aspects = ["deps", "srcs", "data", "implementation_deps", "exports"]
    if hasattr(ctx.rule, "attr"):
        for attr_name in attr_aspects:
            if hasattr(ctx.rule.attr, attr_name):
                val = getattr(ctx.rule.attr, attr_name)
                if type(val) == "list":
                    for dep in val:
                        if LicenseReportInfo in dep:
                            transitive_entries.append(dep[LicenseReportInfo].entries)
                elif type(val) == "Target":
                    if LicenseReportInfo in val:
                        transitive_entries.append(val[LicenseReportInfo].entries)

    return [LicenseReportInfo(
        entries = depset([entry], transitive = transitive_entries),
    )]

license_aspect = aspect(
    implementation = _license_aspect_impl,
    attr_aspects = ["deps", "srcs", "data", "implementation_deps", "exports"],
)

def _license_report_impl(ctx):
    transitive_deps = []
    for dep in ctx.attr.deps:
        if LicenseReportInfo in dep:
            transitive_deps.append(dep[LicenseReportInfo].entries)

    all_entries = depset(transitive = transitive_deps)

    data_by_target = {}
    for entry in all_entries.to_list():
        if entry.target not in data_by_target:
            data_by_target[entry.target] = entry.target_licenses

    output_list = []
    # Collect all unique licenses as well?
    # For now just output simple target list

    # Sort for deterministic output
    sorted_targets = sorted(data_by_target.keys())

    for target_label in sorted_targets:
        target_licenses = data_by_target[target_label]
        output_list.append({
            "target": target_label,
            "licenses": target_licenses,
        })

    content = json.encode_indent(output_list)
    out = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(out, content)
    return [DefaultInfo(files = depset([out]))]

license_report = rule(
    implementation = _license_report_impl,
    attrs = {
        "deps": attr.label_list(aspects = [license_aspect]),
    },
)

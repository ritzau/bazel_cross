"""Rules for generating license reports using supply_chain_tools."""

load("@supply_chain_tools//gather_metadata:gather_metadata.bzl", "gather_metadata_info")
load("@supply_chain_tools//gather_metadata:providers.bzl", "TransitiveMetadataInfo")

# Provider to collect all seen target labels
AllTargetsInfo = provider(
    fields = {"labels": "depset of all seen target labels"},
)

def _serialize_provider(p):
    info = {}

    if hasattr(p, "metadata") and hasattr(p, "files") and not hasattr(p, "attributes"):
        # Likely PackageMetadataInfo
        info["type"] = "package_metadata"
        info["metadata_file"] = p.metadata.path if p.metadata else None
        return info

    if hasattr(p, "attributes") and hasattr(p, "kind"):
        # Likely PackageAttributeInfo
        info["type"] = "attribute"
        info["kind"] = p.kind
        info["attribute_file"] = p.attributes.path if p.attributes else None
        return info

    if hasattr(p, "identifier") and hasattr(p, "name"):
        # Likely LicenseKindInfo
        info["type"] = "license_kind"
        info["id"] = p.identifier
        info["name"] = p.name
        return info

    info["type"] = "unknown"
    info["str"] = str(p)
    return info

def _collect_all_aspect_impl(target, ctx):
    labels = [str(target.label)]
    transitive = []

    # We look at all attributes of the rule
    if hasattr(ctx.rule, "attr"):
        for attr in dir(ctx.rule.attr):
            val = getattr(ctx.rule.attr, attr)
            if type(val) == "Target":
                if AllTargetsInfo in val:
                    transitive.append(val[AllTargetsInfo].labels)
            elif type(val) == "list":
                for item in val:
                    if type(item) == "Target":
                        if AllTargetsInfo in item:
                            transitive.append(item[AllTargetsInfo].labels)

    return [AllTargetsInfo(labels = depset(labels, transitive = transitive))]

collect_all_aspect = aspect(
    implementation = _collect_all_aspect_impl,
    attr_aspects = ["*"],
)

def _license_report_impl(ctx):
    metadata_targets = {}
    all_seen_targets = depset()

    # Process metadata from supply_chain_tools aspect
    for dep in ctx.attr.deps:
        if TransitiveMetadataInfo in dep:
            for twmi in dep[TransitiveMetadataInfo].trans.to_list():
                target_str = str(twmi.target)
                if target_str not in metadata_targets:
                    entry = {
                        "target": target_str,
                        "metadata": [],
                    }
                    if hasattr(twmi, "metadata"):
                        for m in twmi.metadata.to_list():
                            entry["metadata"].append(_serialize_provider(m))
                    metadata_targets[target_str] = entry

        if AllTargetsInfo in dep:
            all_seen_targets = depset(transitive = [all_seen_targets, dep[AllTargetsInfo].labels])

    result = []
    for target in all_seen_targets.to_list():
        if target in metadata_targets:
            result.append(metadata_targets[target])
        else:
            # Report targets even if they have no metadata
            result.append({
                "target": target,
                "metadata": [],
                "status": "no metadata found",
            })

    content = json.encode(result)

    name = "%s_metadata_info.json" % ctx.label.name
    out = ctx.actions.declare_file(name)
    ctx.actions.write(
        output = out,
        content = content,
    )

    return [DefaultInfo(files = depset([out]))]

license_report = rule(
    implementation = _license_report_impl,
    attrs = {
        "deps": attr.label_list(aspects = [gather_metadata_info, collect_all_aspect]),
    },
)

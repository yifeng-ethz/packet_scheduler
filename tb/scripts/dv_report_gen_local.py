#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

SKILL_GEN = Path("/home/yifeng/.codex/skills/dv-workflow/scripts/dv_report_gen.py")
TB_DIR = Path(__file__).resolve().parents[1]


def load_base():
    spec = importlib.util.spec_from_file_location("dv_report_gen_base", SKILL_GEN)
    if spec is None or spec.loader is None:
        raise SystemExit(f"failed to load base dv_report_gen from {SKILL_GEN}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


base = load_base()


def catalog_planned(bucket: dict[str, Any]) -> int:
    return int(bucket.get("catalog_planned_cases", bucket.get("planned_cases", 0)))


def promoted_cases(bucket: dict[str, Any]) -> int:
    return int(bucket.get("promoted_cases", bucket.get("planned_cases", len(bucket.get("cases", [])))))


def evidenced_cases(bucket: dict[str, Any]) -> int:
    return int(bucket.get("evidenced_cases", 0))


def catalog_pending(bucket: dict[str, Any]) -> int:
    return int(bucket.get("catalog_pending_cases", max(catalog_planned(bucket) - promoted_cases(bucket), 0)))


def bucket_status(bucket: dict[str, Any]) -> str:
    promoted = promoted_cases(bucket)
    evidenced = evidenced_cases(bucket)
    if promoted == 0:
        return base.PEND_EMOJI
    if evidenced < promoted:
        return base.WARN_EMOJI
    if catalog_pending(bucket) > 0:
        return base.WARN_EMOJI
    merged = bucket.get("merged_bucket_total") or {}
    for key, target in base.TARGETS.items():
        value = merged.get(key)
        if isinstance(value, dict) and value.get("pct", 0.0) < target:
            return base.WARN_EMOJI
    return base.PASS_EMOJI


def display_case_id(case: dict[str, Any]) -> str:
    return (
        case.get("report_case_id")
        or case.get("full_case_id")
        or case.get("case_id")
        or case.get("legacy_test_name")
        or "case"
    )


def legacy_case_name(case: dict[str, Any]) -> str:
    return case.get("legacy_test_name") or case.get("test_name") or display_case_id(case)


def pass_string(case: dict[str, Any]) -> str:
    if case.get("passed") is True:
        return "pass"
    if case.get("passed") is False:
        return "fail"
    return "pending"


def fmt_scope_value(value: Any) -> str:
    if isinstance(value, list):
        return ", ".join(f"`{item}`" for item in value)
    if isinstance(value, dict):
        return ", ".join(f"`{k}={v}`" for k, v in value.items())
    return f"`{value}`"


def format_artifact_ref(tb_rel_path: str) -> str:
    tb_path = TB_DIR / tb_rel_path
    if tb_path.exists():
        return f"[`{tb_rel_path}`](../../{tb_rel_path})"
    return f"`missing: {tb_rel_path}`"


def render_scope_table(data: dict[str, Any]) -> list[str]:
    scope = data.get("signoff_scope") or {}
    out = [
        "## Signoff Scope",
        "",
        "| field | claimed value |",
        "|---|---|",
    ]
    for key, value in scope.items():
        out.append(f"| {key} | {fmt_scope_value(value)} |")
    return out


def render_non_claims(data: dict[str, Any]) -> list[str]:
    non_claims = data.get("non_claims") or {}
    out = [
        "## Non-Claims",
        "",
    ]
    for key, value in non_claims.items():
        label = key.replace("_", " ")
        if isinstance(value, list):
            out.append(f"- {label}: " + ", ".join(f"`{item}`" for item in value))
        else:
            out.append(f"- {label}: {value}")
    return out


def render_category_status(data: dict[str, Any]) -> list[str]:
    category_status = data.get("coverage_category_status") or {}
    out = [
        "## Coverage Category Status",
        "",
        "| metric | status | note |",
        "|---|---|---|",
    ]
    for metric, note in (category_status.get("supported_with_targets") or {}).items():
        out.append(f"| {metric} | supported_with_target | {note} |")
    for metric, note in (category_status.get("supported_without_hard_target") or {}).items():
        out.append(f"| {metric} | supported_no_fixed_target | {note} |")
    unsupported = category_status.get("unsupported") or {}
    if unsupported:
        for metric, note in unsupported.items():
            out.append(f"| {metric} | unsupported | {note} |")
    else:
        out.append(f"| - | unsupported | none; no code-coverage category is silently omitted from this report |")
    return out


def fmt_instance_metrics(summary: dict[str, Any]) -> str:
    metrics = summary.get("metrics") or {}
    ordered = []
    for key in ("stmt", "branch", "cond", "fsm_trans", "toggle"):
        value = metrics.get(key)
        if value is not None:
            ordered.append(f"{key}={value:.2f}")
    count = summary.get("instance_count", 0)
    suffix = f" (min across {count} instance{'s' if count != 1 else ''})"
    return ", ".join(ordered) + suffix if ordered else f"n/a{suffix}"


def render_hole_disposition(data: dict[str, Any]) -> list[str]:
    disposition = data.get("coverage_hole_disposition") or []
    out = [
        "## Coverage-Hole Disposition",
        "",
    ]
    if not disposition:
        out.append(f"{base.PEND_EMOJI} no merged-UCDB hole classification recorded yet.")
        return out

    out += [
        "| area | measured summary | disposition | evidence anchor | next action |",
        "|---|---|---|---|---|",
    ]
    for item in disposition:
        out.append(
            "| {area} | {summary} | {disp}: {reason} | {anchor} | {action} |".format(
                area=item.get("area", "?"),
                summary=fmt_instance_metrics(item.get("instance_summary") or {}),
                disp=item.get("classification", "?"),
                reason=item.get("reason", ""),
                anchor=item.get("evidence_anchor", ""),
                action=item.get("next_action", ""),
            )
        )
    return out


def link_case(case_id: str, prefix: str) -> str:
    return f"[`{case_id}`]({prefix}{case_id}.md)"


def ordered_case_links(case_ids: list[str], prefix: str) -> str:
    return ", ".join(link_case(case_id, prefix) for case_id in case_ids)


def render_case(case: dict[str, Any], tb_rel_log: str, tb_rel_ucdb: str) -> str:
    st = base.case_status(case)
    cid = display_case_id(case)
    bucket = case.get("bucket", "?")
    method = case.get("method", "?")
    impl_mode = case.get("implementation_mode", "?")
    build_tag = case.get("build_tag", "?")
    effort = case.get("isolated_effort", "?")
    obs = case.get("observed_txn", 0)
    scenario = case.get("scenario") or case.get("description") or ""
    primary = case.get("primary_checks") or ""
    anchor = case.get("contract_anchor") or ""
    log_summary = case.get("log_summary") or {}
    build_knobs = case.get("build_knobs") or {}

    out = [
        f"# {st} {cid}",
        "",
        f"**Bucket:** `{bucket}` &nbsp; **Method:** `{method}` &nbsp; **Build:** `{build_tag}` &nbsp; **Effort:** `{effort}` &nbsp; **Result:** `{pass_string(case)}`",
        "",
        "## Intent",
        "",
        f"- **Scenario:** {scenario}",
    ]
    if primary:
        out.append(f"- **Primary checks:** {primary}")
    if anchor:
        out.append(f"- **Contract anchor:** {anchor}")

    out += [
        "",
        "## Execution Evidence",
        "",
        "| status | field | value |",
        "|:---:|---|---|",
        f"| {st} | report_case_id | `{cid}` |",
        f"| {base.INFO_EMOJI} | legacy_test_name | `{legacy_case_name(case)}` |",
        f"| {base.INFO_EMOJI} | observed_txn | `{obs}` |",
        f"| {base.INFO_EMOJI} | implementation_mode | `{impl_mode}` |",
        f"| {base.INFO_EMOJI} | log | {format_artifact_ref(tb_rel_log)} |",
        f"| {base.INFO_EMOJI} | ucdb | {format_artifact_ref(tb_rel_ucdb)} |",
    ]
    for key, value in build_knobs.items():
        out.append(f"| {base.INFO_EMOJI} | build_knobs.{key} | `{value}` |")
    for key, value in log_summary.items():
        out.append(f"| {base.INFO_EMOJI} | log.{key} | `{value}` |")

    out += [
        "",
        "## Coverage",
        "",
        "| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |",
        "|---|---|---|---|---|---|",
    ]
    per_metric = {
        "standalone_coverage": case.get("standalone_coverage") or {},
        "isolated_cov_per_txn": case.get("isolated_cov_per_txn") or {},
        "bucket_gain_by_case": case.get("bucket_gain_by_case") or {},
        "bucket_merged_total_after_case": case.get("bucket_merged_total_after_case") or {},
        "bucket_gain_per_txn": case.get("bucket_gain_per_txn") or {},
    }
    for key in base.COV_KEYS:
        row = [key]
        for source in (
            "standalone_coverage",
            "isolated_cov_per_txn",
            "bucket_gain_by_case",
            "bucket_merged_total_after_case",
            "bucket_gain_per_txn",
        ):
            value = per_metric[source].get(key)
            if isinstance(value, dict) and "pct" in value:
                row.append(f"{value['pct']:.2f}")
            else:
                row.append("n/a")
        out.append("| " + " | ".join(row) + " |")

    out += [
        "",
        "---",
        f"_Back to [bucket](../buckets/{bucket}.md) &middot; [dashboard](../../DV_REPORT.md)_",
    ]
    return "\n".join(out)


def render_bucket(bucket_name: str, bucket: dict[str, Any]) -> str:
    st = bucket_status(bucket)
    planned = catalog_planned(bucket)
    promoted = promoted_cases(bucket)
    evidenced = evidenced_cases(bucket)
    ordered_case_ids = bucket.get("ordered_case_ids") or []
    tot = bucket.get("merged_bucket_total") or {}

    out = [
        f"# {st} {bucket_name} bucket",
        "",
        f"**Catalog planned:** `{planned}` &nbsp; **Promoted:** `{promoted}` &nbsp; **Evidenced:** `{evidenced}` &nbsp; **Catalog backlog:** `{catalog_pending(bucket)}` &nbsp; **Status:** {st}",
        "",
        "## Catalog Inventory",
        "",
        f"- source: [`{bucket.get('catalog_source','?')}`](../../{bucket.get('catalog_source','')})",
        f"- summary: {bucket.get('catalog_summary','n/a')}",
        "",
        "## Ordered isolated baseline",
        "",
        f"- execution order: {ordered_case_links(ordered_case_ids, '../cases/')}",
        "",
        "## Merged code coverage (this bucket)",
        "",
        "| status | metric | merged_pct | target |",
        "|:---:|---|---|---|",
    ]
    for key in base.COV_KEYS:
        value = tot.get(key)
        pct = value["pct"] if isinstance(value, dict) and "pct" in value else None
        target = base.TARGETS.get(key)
        target_str = f"{target:.1f}" if target is not None else "-"
        if pct is None:
            out.append(f"| {base.PEND_EMOJI} | {key} | n/a | {target_str} |")
        else:
            out.append(f"| {base.target_status(key, pct)} | {key} | {pct:.2f} | {target_str} |")

    out += [
        "",
        "## Ordered merge trace",
        "",
        "| status | step | report_case_id | legacy_test_name | merged_total | detail |",
        "|:---:|---:|---|---|---|---|",
    ]
    cases_by_id = {display_case_id(case): case for case in bucket.get("cases", [])}
    for step in bucket.get("merge_trace") or []:
        cid = step.get("full_case_id", step.get("case_id", "?"))
        case = cases_by_id.get(cid, {})
        out.append(
            f"| {base.case_status(case) if case else base.INFO_EMOJI} | {step.get('step','?')} | `{cid}` | `{step.get('legacy_test_name', legacy_case_name(case))}` | {base.fmt_cov(step.get('merged_total_after_case'))} | [case](../cases/{cid}.md) |"
        )

    out += [
        "",
        "---",
        "_Back to [dashboard](../../DV_REPORT.md)_",
    ]
    return "\n".join(out)


def render_execution_mode(mode_name: str, mode: dict[str, Any], case_prefix: str) -> list[str]:
    out = [
        f"### {mode_name}",
        "",
    ]
    bucket_order = mode.get("bucket_order") or []
    if bucket_order:
        out.append("- bucket_order: " + ", ".join(f"`{bucket}`" for bucket in bucket_order))
    per_bucket = mode.get("per_bucket_case_order") or {}
    if per_bucket:
        for bucket, case_ids in per_bucket.items():
            out.append(f"- {bucket}: {ordered_case_links(case_ids, case_prefix)}")
    ordered_steps = mode.get("ordered_steps") or []
    if ordered_steps:
        out.append("- ordered_steps:")
        for step in ordered_steps:
            out.append(
                f"  `{step.get('bucket','?')}` -> {link_case(step.get('report_case_id','?'), case_prefix)} (`{step.get('legacy_test_name','?')}`)"
            )
    extra_tail = mode.get("extra_tail_steps") or []
    if extra_tail:
        for step in extra_tail:
            out.append(
                f"- extra_tail: `{step.get('bucket','?')}` -> `{step.get('legacy_step_name','?')}` ({step.get('description','')})"
            )
    for limitation in mode.get("limitations") or []:
        out.append(f"- limitation: {limitation}")
    return out


def render_signoff_run(run: dict[str, Any], execution_mode: dict[str, Any] | None) -> str:
    run_id = run.get("run_id", "run")
    kind = run.get("kind", "?")
    build = run.get("build_tag", "?")
    seq = run.get("sequence_name") or "-"
    cov = run.get("code_coverage") or {}
    cross = run.get("cross_summary") or {}

    pct = cross.get("pct")
    failed = cross.get("counter_checks_failed", 0) or 0
    unexpected = cross.get("unexpected_outputs", 0) or 0
    if failed > 0 or unexpected > 0:
        st = base.FAIL_EMOJI
    elif pct is not None and pct < 50.0:
        st = base.WARN_EMOJI
    else:
        st = base.PASS_EMOJI

    out = [
        f"# {st} {run_id}",
        "",
        f"**Kind:** `{kind}` &nbsp; **Build:** `{build}` &nbsp; **Sequence:** `{seq}`",
        "",
        "## Summary",
        "",
        "| status | field | value |",
        "|:---:|---|---|",
        f"| {base.INFO_EMOJI} | case_count | `{run.get('case_count',0)}` |",
        f"| {base.INFO_EMOJI} | effort | `{run.get('effort','?')}` |",
        f"| {base.INFO_EMOJI} | txns | `{cross.get('txns',0)}` |",
        f"| {st} | functional_cross_pct | `{pct if pct is not None else 'n/a'}` |",
        f"| {'✅' if failed == 0 else '❌'} | counter_checks_failed | `{failed}` |",
        f"| {'✅' if unexpected == 0 else '❌'} | unexpected_outputs | `{unexpected}` |",
    ]
    for limitation in run.get("limitations") or []:
        out.append(f"| {base.WARN_EMOJI} | limitation | {limitation} |")

    out += [
        "",
        "## Execution Order",
        "",
    ]
    if execution_mode:
        out.extend(render_execution_mode(kind, execution_mode, "../cases/"))
    else:
        out.append(f"{base.PEND_EMOJI} no execution-order metadata recorded for this run.")

    out += [
        "",
        "## Code coverage",
        "",
        "| metric | pct |",
        "|---|---|",
    ]
    for key in base.COV_KEYS:
        value = cov.get(key)
        if isinstance(value, dict) and "pct" in value:
            out.append(f"| {key} | {value['pct']:.2f} |")
        else:
            out.append(f"| {key} | n/a |")

    out += [
        "",
        "## Transaction growth curve",
        "",
    ]
    curve_rows = base.parse_curve(cross.get("curve", ""))
    if not curve_rows:
        out.append(f"{base.PEND_EMOJI} no curve data available for this run.")
    else:
        out += [
            "| txn | case | seq | pct | delta_bins | reason |",
            "|---:|---|---|---|---:|---|",
        ]
        for row in curve_rows:
            out.append(
                "| {txn} | `{case}` | `{seq}` | {pct} | {delta_bins} | {reason} |".format(
                    txn=row.get("txn", "?"),
                    case=row.get("case", ""),
                    seq=row.get("seq", ""),
                    pct=row.get("pct", ""),
                    delta_bins=row.get("delta_bins", ""),
                    reason=row.get("reason", ""),
                )
            )

    out += [
        "",
        "---",
        "_Back to [dashboard](../../DV_REPORT.md)_",
    ]
    return "\n".join(out)


def render_report_readme(data: dict[str, Any]) -> str:
    totals = data.get("totals") or {}
    merged = totals.get("merged_total_code_coverage") or {}
    func = totals.get("functional_coverage") or {}
    random_cases = data.get("random_cases") or []
    out = [
        f"# {data.get('report_title', 'DUT')} — REPORT index",
        "",
        f"**DUT:** `{data.get('dut_name','?')}` &nbsp; **Date:** `{data.get('date','?')}` &nbsp; **RTL variant:** `{data.get('rtl_variant','?')}` &nbsp; **Seed:** `{data.get('seed','?')}`",
        "",
        f"{base.PASS_EMOJI} pass / closed / target met &middot; {base.WARN_EMOJI} partial / below target / known limitation &middot; {base.FAIL_EMOJI} failed / missing evidence &middot; {base.PEND_EMOJI} pending &middot; {base.INFO_EMOJI} informational",
        "",
    ]
    out.extend(render_scope_table(data))
    out += [
        "",
        "## Buckets",
        "",
        "| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |",
        "|:---:|---|---:|---:|---:|---:|---|",
    ]
    for summary in data.get("bucket_summary", []):
        bucket_name = summary.get("bucket")
        detail = (data.get("buckets") or {}).get(bucket_name, {})
        out.append(
            f"| {bucket_status(detail) if detail else base.INFO_EMOJI} | [`{bucket_name}`](buckets/{bucket_name}.md) | {summary.get('catalog_planned_cases',0)} | {summary.get('promoted_cases',0)} | {summary.get('evidenced_cases',0)} | {summary.get('catalog_pending_cases',0)} | {base.fmt_cov(summary.get('merged_bucket_total'))} |"
        )
    out += [
        "",
        "## Signoff runs",
        "",
        "| status | run_id | kind | seq | txns | cross_pct |",
        "|:---:|---|---|---|---:|---:|",
    ]
    for run in data.get("signoff_runs", []):
        cross = run.get("cross_summary") or {}
        failed = cross.get("counter_checks_failed", 0) or 0
        unexpected = cross.get("unexpected_outputs", 0) or 0
        if failed > 0 or unexpected > 0:
            st = base.FAIL_EMOJI
        elif cross.get("pct") is not None and cross.get("pct", 0.0) < 50.0:
            st = base.WARN_EMOJI
        else:
            st = base.PASS_EMOJI
        out.append(
            f"| {st} | [`{run.get('run_id','?')}`](cross/{base.slug(run.get('run_id','run'))}.md) | {run.get('kind','?')} | {run.get('sequence_name','-')} | {cross.get('txns',0)} | {cross.get('pct','n/a')} |"
        )
    out += [
        "",
        "## Totals",
        "",
        f"- catalog_planned_cases: `{totals.get('catalog_planned_cases','?')}`",
        f"- promoted_signoff_cases: `{totals.get('promoted_cases','?')}`",
        f"- catalog_pending_cases: `{totals.get('catalog_pending_cases','?')}`",
        f"- evidenced_promoted_cases: `{totals.get('evidenced_cases','?')}`",
        f"- excluded_cases: `{totals.get('excluded_cases','?')}`",
        f"- promoted_random_cases: `{len(random_cases)}`",
        f"- merged total code coverage across promoted isolated evidence: `{base.fmt_cov(merged)}`",
        f"- promoted functional coverage: `{func.get('pct','?')}% ({func.get('evidenced','?')}/{func.get('planned','?')})`",
        "",
        "---",
        "_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_",
    ]
    return "\n".join(out)


def render_txn_growth_index(data: dict[str, Any]) -> str:
    random_cases = data.get("random_cases") or []
    out = [
        f"# {data.get('report_title', 'DUT')} — txn_growth index",
        "",
    ]
    if not random_cases:
        out += [
            "No promoted random signoff cases are present in the active native-SV report set.",
            "The current promoted buckets are directed-only, so no checkpoint-UCDB growth pages are required.",
        ]
    else:
        out += [
            "Promoted random testcase checkpoint curves:",
            "",
        ]
        for rc in random_cases:
            cid = display_case_id(rc)
            out.append(f"- [`{cid}`]({cid}.md)")
    return "\n".join(out)


def render_dashboard(data: dict[str, Any]) -> str:
    totals = data.get("totals") or {}
    merged = totals.get("merged_total_code_coverage") or {}
    func = totals.get("functional_coverage") or {}
    impl = data.get("implementation_summary") or {}
    failed_cases = data.get("failed_cases") or []
    signoff_failures = sum(
        1
        for run in (data.get("signoff_runs") or [])
        if ((run.get("cross_summary") or {}).get("counter_checks_failed") or 0) > 0
        or ((run.get("cross_summary") or {}).get("unexpected_outputs") or 0) > 0
    )
    overall = base.FAIL_EMOJI if failed_cases or signoff_failures else base.PASS_EMOJI

    out = [
        f"# {overall} DV Report — {data.get('report_title', 'DUT')}",
        "",
        f"**DUT:** `{data.get('dut_name','?')}` &nbsp; **Date:** `{data.get('date','?')}` &nbsp; **RTL variant:** `{data.get('rtl_variant','?')}` &nbsp; **Seed:** `{data.get('seed','?')}`",
        "",
        "This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).",
        "",
        "## Legend",
        "",
        "✅ pass / closed &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational",
        "",
        "## Health",
        "",
        "| status | field | value |",
        "|:---:|---|---|",
        f"| {'❌' if failed_cases else '✅'} | failed_cases | `{len(failed_cases)}` |",
        f"| {'❌' if signoff_failures else '✅'} | signoff_runs_with_failures | `{signoff_failures}` |",
        f"| {'⚠️' if totals.get('catalog_pending_cases',0) else '✅'} | catalog_backlog_cases | `{totals.get('catalog_pending_cases',0)}` |",
        f"| {'⚠️' if impl.get('unimplemented_count',0) else '✅'} | unimplemented_cases | `{impl.get('unimplemented_count',0)}` |",
        f"| {'⚠️' if impl.get('stale_artifact_without_engine_marker_count',0) else '✅'} | stale_artifacts | `{impl.get('stale_artifact_without_engine_marker_count',0)}` |",
        "",
    ]
    out.extend(render_scope_table(data))
    out += [""] + render_non_claims(data) + [
        "",
        "## Bucket Summary",
        "",
        "| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |",
        "|:---:|---|---:|---:|---:|---:|---|---|",
    ]
    for summary in data.get("bucket_summary", []):
        bucket_name = summary.get("bucket")
        detail = (data.get("buckets") or {}).get(bucket_name, {})
        fcov = summary.get("functional_coverage") or {}
        out.append(
            f"| {bucket_status(detail) if detail else base.INFO_EMOJI} | [`{bucket_name}`](REPORT/buckets/{bucket_name}.md) | {summary.get('catalog_planned_cases',0)} | {summary.get('promoted_cases',0)} | {summary.get('evidenced_cases',0)} | {summary.get('catalog_pending_cases',0)} | {base.fmt_cov(summary.get('merged_bucket_total'))} | {fcov.get('pct','?')}% ({fcov.get('evidenced','?')}/{fcov.get('planned','?')}) |"
        )

    out += [
        "",
        "## Totals",
        "",
        "| status | metric | pct | target |",
        "|:---:|---|---|---|",
    ]
    for key in base.COV_KEYS:
        value = merged.get(key)
        if isinstance(value, dict) and "pct" in value:
            out.append(
                f"| {base.target_status(key, value['pct'])} | {key} | {value['pct']:.2f} | {base.TARGETS.get(key, '-')} |"
            )
        else:
            out.append(f"| {base.PEND_EMOJI} | {key} | n/a | {base.TARGETS.get(key, '-')} |")
    out += [
        "",
        f"- catalog_planned_cases: `{totals.get('catalog_planned_cases','?')}`",
        f"- promoted_signoff_cases: `{totals.get('promoted_cases','?')}`",
        f"- evidenced_promoted_cases: `{totals.get('evidenced_cases','?')}`",
        f"- promoted functional coverage: `{func.get('pct','?')}% ({func.get('evidenced','?')}/{func.get('planned','?')})`",
        "",
        "## Signoff Runs",
        "",
        "| status | run_id | kind | build | seq | txns | cross_pct |",
        "|:---:|---|---|---|---|---:|---:|",
    ]
    for run in data.get("signoff_runs", []):
        cross = run.get("cross_summary") or {}
        failed = cross.get("counter_checks_failed", 0) or 0
        unexpected = cross.get("unexpected_outputs", 0) or 0
        if failed > 0 or unexpected > 0:
            st = base.FAIL_EMOJI
        elif cross.get("pct") is not None and cross.get("pct", 0.0) < 50.0:
            st = base.WARN_EMOJI
        else:
            st = base.PASS_EMOJI
        out.append(
            f"| {st} | [`{run.get('run_id','?')}`](REPORT/cross/{base.slug(run.get('run_id','run'))}.md) | {run.get('kind','?')} | {run.get('build_tag','?')} | {run.get('sequence_name','-')} | {cross.get('txns',0)} | {cross.get('pct','n/a')} |"
        )

    out += [
        "",
        "## Index",
        "",
        "- [`REPORT/README.md`](REPORT/README.md) — reviewer entry point",
        "- [`REPORT/buckets/`](REPORT/buckets/) — ordered-merge trace per bucket",
        "- [`REPORT/cases/`](REPORT/cases/) — one page per stable report case ID",
        "- [`REPORT/cross/`](REPORT/cross/) — one page per signoff run",
        "- [`DV_COV.md`](DV_COV.md) — coverage totals, ordering, and baseline scope",
        "- [`DV_REPORT.json`](DV_REPORT.json) — machine-readable source of truth",
        "",
        "_This dashboard is generated by `python3 tb/scripts/dv_report_gen_local.py --tb tb`. Edits are overwritten; fix the JSON or the local generator instead._",
    ]
    return "\n".join(out)


def render_covmd(data: dict[str, Any]) -> str:
    totals = data.get("totals") or {}
    merged = totals.get("merged_total_code_coverage") or {}
    execution_modes = data.get("execution_modes") or {}

    out = [
        f"# DV Coverage Summary — {data.get('report_title', 'DUT')}",
        "",
        "This page is the coverage summary only. Per-case incremental coverage lives under",
        "[`REPORT/cases/`](REPORT/cases/); per-bucket ordered-merge traces live under",
        "[`REPORT/buckets/`](REPORT/buckets/).",
        "",
        "## Legend",
        "",
        "✅ pass / closed &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational",
        "",
    ]
    out.extend(render_scope_table(data))
    out += [""] + render_non_claims(data) + [""] + render_category_status(data) + [""] + render_hole_disposition(data) + [
        "",
        "## Targets vs merged totals",
        "",
        "<!-- merged_pct = merge across all evidenced promoted isolated-mode UCDBs across all signoff buckets. -->",
        "",
        "| status | metric | merged_pct | target |",
        "|:---:|---|---|---|",
    ]
    for key in base.COV_KEYS:
        value = merged.get(key)
        target = base.TARGETS.get(key)
        target_str = f"{target:.1f}" if target is not None else "-"
        if isinstance(value, dict) and "pct" in value:
            out.append(f"| {base.target_status(key, value['pct'])} | {key} | {value['pct']:.2f} | {target_str} |")
        else:
            out.append(f"| {base.PEND_EMOJI} | {key} | n/a | {target_str} |")

    out += [
        "",
        "## Per-bucket merged totals",
        "",
        "| status | bucket | catalog_planned | promoted | evidenced | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |",
        "|:---:|---|---:|---:|---:|---|---|---|---|---|---|---|",
    ]
    for summary in data.get("bucket_summary", []):
        bucket_name = summary.get("bucket")
        detail = (data.get("buckets") or {}).get(bucket_name, {})
        row = [
            bucket_status(detail) if detail else base.INFO_EMOJI,
            f"[`{bucket_name}`](REPORT/buckets/{bucket_name}.md)",
            str(summary.get("catalog_planned_cases", 0)),
            str(summary.get("promoted_cases", 0)),
            str(summary.get("evidenced_cases", 0)),
        ]
        for key in base.COV_KEYS:
            value = (summary.get("merged_bucket_total") or {}).get(key)
            row.append(f"{value['pct']:.2f}" if isinstance(value, dict) and "pct" in value else "n/a")
        out.append("| " + " | ".join(row) + " |")

    out += [
        "",
        "## Isolated execution order and traceability",
        "",
        "| bucket | ordered case IDs | trace |",
        "|---|---|---|",
    ]
    for summary in data.get("bucket_summary", []):
        bucket_name = summary.get("bucket")
        case_ids = summary.get("ordered_case_ids") or ((data.get("buckets") or {}).get(bucket_name, {}).get("ordered_case_ids") or [])
        out.append(
            f"| {bucket_name} | {ordered_case_links(case_ids, 'REPORT/cases/')} | [`REPORT/buckets/{bucket_name}.md`](REPORT/buckets/{bucket_name}.md) |"
        )

    out += [
        "",
        "## Signoff runs by build",
        "",
        "| status | run_id | kind | build | case_count | stmt | branch | toggle | functional_cross_pct | txns |",
        "|:---:|---|---|---|---:|---|---|---|---:|---:|",
    ]
    for run in data.get("signoff_runs", []):
        cov = run.get("code_coverage") or {}
        cross = run.get("cross_summary") or {}
        failed = cross.get("counter_checks_failed", 0) or 0
        unexpected = cross.get("unexpected_outputs", 0) or 0
        if failed > 0 or unexpected > 0:
            st = base.FAIL_EMOJI
        elif cross.get("pct") is not None and cross.get("pct", 0.0) < 50.0:
            st = base.WARN_EMOJI
        else:
            st = base.PASS_EMOJI
        def metric_pct(key: str) -> str:
            value = cov.get(key)
            return f"{value['pct']:.2f}" if isinstance(value, dict) and "pct" in value else "n/a"
        out.append(
            f"| {st} | [`{run.get('run_id','?')}`](REPORT/cross/{base.slug(run.get('run_id','run'))}.md) | {run.get('kind','?')} | {run.get('build_tag','?')} | {run.get('case_count',0)} | {metric_pct('stmt')} | {metric_pct('branch')} | {metric_pct('toggle')} | {cross.get('pct','n/a')} | {cross.get('txns',0)} |"
        )

    out += [
        "",
        "## Fixed baseline execution order",
        "",
    ]
    for mode_name in ("bucket_frame", "all_buckets_frame"):
        mode = execution_modes.get(mode_name)
        if mode:
            out.extend(render_execution_mode(mode_name, mode, "REPORT/cases/"))
            out.append("")

    out += [
        "_Regenerate with `python3 tb/scripts/dv_report_gen_local.py --tb tb`._",
    ]
    return "\n".join(out)


def clean_generated_tree(report: Path) -> None:
    for rel in ("buckets", "cases", "cross", "txn_growth"):
        directory = report / rel
        directory.mkdir(parents=True, exist_ok=True)
        for child in directory.glob("*.md"):
            child.unlink()
    readme = report / "README.md"
    if readme.exists():
        readme.unlink()


def main() -> int:
    ap = base.argparse.ArgumentParser(description="Local OPQ DV report generator")
    ap.add_argument("--tb", required=True, help="path to the IP tb/ directory")
    ap.add_argument("--json", default=None, help="override DV_REPORT.json path")
    args = ap.parse_args()

    tb = Path(args.tb).resolve()
    json_path = Path(args.json) if args.json else tb / "DV_REPORT.json"
    data = json.loads(json_path.read_text(encoding="utf-8"))
    report = tb / "REPORT"
    clean_generated_tree(report)

    seed = data.get("seed", 1)
    execution_modes = data.get("execution_modes") or {}

    for bucket_name, bucket in (data.get("buckets") or {}).items():
        for case in bucket.get("cases", []):
            cid = display_case_id(case)
            log_rel = f"uvm/logs/{cid}_{data.get('rtl_variant','after')}_s{seed}.log"
            ucdb_rel = f"uvm/cov_after/{cid}_s{seed}.ucdb"
            base.write(report / "cases" / f"{cid}.md", render_case(case, log_rel, ucdb_rel))
        base.write(report / "buckets" / f"{bucket_name}.md", render_bucket(bucket_name, bucket))

    for rc in data.get("random_cases") or []:
        cid = display_case_id(rc)
        case_path = report / "cases" / f"{cid}.md"
        if not case_path.exists():
            log_rel = f"uvm/logs/{cid}_{data.get('rtl_variant','after')}_s{seed}.log"
            ucdb_rel = f"uvm/cov_after/{cid}_s{seed}.ucdb"
            base.write(case_path, render_case(rc, log_rel, ucdb_rel))
        base.write(report / "txn_growth" / f"{cid}.md", base.render_txn_growth(rc))
    base.write(report / "txn_growth" / "README.md", render_txn_growth_index(data))

    signoff_modes = {
        mode.get("run_id"): mode
        for mode in execution_modes.values()
        if isinstance(mode, dict) and mode.get("run_id")
    }
    for run in data.get("signoff_runs") or []:
        base.write(
            report / "cross" / f"{base.slug(run.get('run_id','run'))}.md",
            render_signoff_run(run, signoff_modes.get(run.get("run_id"))),
        )

    base.write(report / "README.md", render_report_readme(data))
    base.write(tb / "DV_REPORT.md", render_dashboard(data))
    base.write(tb / "DV_COV.md", render_covmd(data))

    print(
        f"generated {report} (buckets={len(data.get('buckets') or {})}, "
        f"cases={sum(len(bucket.get('cases', [])) for bucket in (data.get('buckets') or {}).values())}, "
        f"random={len(data.get('random_cases') or [])}, "
        f"signoff_runs={len(data.get('signoff_runs') or [])})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

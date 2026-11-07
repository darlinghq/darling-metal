#!/bin/bash
# Syntax-check darling-metal ObjC sources using the flags of a REAL Darling compile
# rule, taken read-only from:
#   cd /home/cristi/src/darling/build && ninja -t commands | grep -m1 cocotron/QuartzCore/CARenderer.m
#
# Nothing under /home/cristi/src/darling is written; only -fsyntax-only is run, so
# no objects and no dependency files are produced either.
#
# The real rule points <Metal/...> at darling's own src/external/metal copy. Those
# -I dirs are REPLACED by this clone's include/private-include/deps/indium dirs and
# HOISTED to the front of the search order, so the stale installed snapshot that
# -I/home/cristi/src/darling/framework-include resolves to cannot shadow the
# headers under test. The negative control at the end proves that hoist is
# load-bearing: without it the check must FAIL.

set -uo pipefail

DM=/home/cristi/src/darling-metal-pr-metalapi
D=/home/cristi/src/darling
WORK=$(cd "$(dirname "$0")" && pwd)

cd "$D/build" || exit 2
# grep -m1 closes the pipe early, which SIGPIPEs ninja and trips `set -o pipefail`,
# so materialise the whole command list first and select from the file.
ninja -t commands > "$WORK/coco-cc-all.txt" 2>/dev/null || exit 2
grep -m1 'cocotron/QuartzCore/CARenderer.m' "$WORK/coco-cc-all.txt" > "$WORK/coco-cc.txt" || exit 2
[ -s "$WORK/coco-cc.txt" ] || exit 2
cd "$WORK" || exit 2

# Drop the input file, the -o/-c pair and the -MD/-MT/-MF dependency trio. The
# -I dirs of the component under test stay in the list and are rewritten below.
# ninja separates some arguments with a tab, so split on both.
mapfile -t RAW < <(tr ' \t' '\n' < "$WORK/coco-cc.txt" \
	| grep -v -e '^-o$' -e '^-c$' -e '^-MD$' -e '^-MT$' -e '^-MF$' \
	         -e '^src/external/cocotron' -e '^QuartzCore_EXPORTS$' -e '^$')

# Rewrite the component's -I dirs onto this clone, and remember them in order.
MINE=()
OUT=()
for f in "${RAW[@]}"; do
	case "$f" in
		-I"$D/src/external/metal")                      v="$DM" ;;
		-I"$D/src/external/metal/include")              v="$DM/include" ;;
		-I"$D/src/external/metal/private-include")      v="$DM/private-include" ;;
		-I"$D/src/external/metal/deps/indium/include")  v="$DM/deps/indium/include" ;;
		-I"$D/src/external/metal/deps/indium/private-include") v="$DM/deps/indium/private-include" ;;
		*) OUT+=("$f"); continue ;;
	esac
	[ -d "$v" ] || { echo "missing $v" >&2; exit 2; }
	case " ${MINE[*]-} " in
		*" -I$v "*) continue ;;
	esac
	case " ${MINE[*]-} " in
		*" -I$v "*) continue ;;
	esac
	# public headers first, so <Metal/Foo.h> is looked for before private-include
	if [ "$v" = "$DM/include" ]; then MINE=("-I$v" "${MINE[@]}"); else MINE+=("-I$v"); fi
done
[ "${#MINE[@]}" -gt 0 ] || { echo "found no component -I dirs to hoist" >&2; exit 2; }
FLAGS=("${MINE[@]}" "${OUT[@]}")

echo "### where <Metal/...> resolves from, in the order clang will try it"
for d in "${MINE[@]}"; do printf '    %s%s\n' "${d#-I}" "$([ -d "${d#-I}/Metal" ] || printf '   (no Metal/ here)')"; done
for f in "${OUT[@]}"; do
	[ "${f#-I}" = "$f" ] && continue
	[ -d "${f#-I}/Metal" ] && printf '    %s   <- STALE installed snapshot\n' "${f#-I}"
done
echo

# Only the Metal framework's own sources: those are what this change touches.
# MetalKit needs extra -I dirs that live in MetalKit's own compile rule, not
# QuartzCore's, so it is out of scope here.
mapfile -t SOURCES < <(cd "$DM" && ls src/Metal/*.mm)

# Warnings that come from the environment rather than from these sources: -fsyntax-only
# leaves the linker's inputs unused, and the SDK/darling header overlay redefines
# TargetConditionals macros and trips a selector-name warning in QuartzCore.
NOISE='linker. input unused|TargetConditionals.h:[0-9]+:[0-9]+: warning|used as the name of the previous parameter'

run() {
	local label=$1 modeflag=$2
	local fail=0 warn_total=0
	for f in "${SOURCES[@]}"; do
		out=$(clang "${FLAGS[@]}" "$modeflag" -fsyntax-only "$DM/$f" 2>&1)
		rc=$?
		kept=$(printf '%s\n' "$out" | grep -E 'error:|warning:' | grep -Ev "$NOISE")
		warn=$(printf '%s\n' "$kept" | grep -c 'warning:')
		if [ $rc -ne 0 ]; then
			echo "FAIL [$label] $f"
			printf '%s\n' "$out" | grep -E 'error:' | head -8
			fail=1
		elif [ "$warn" != 0 ]; then
			echo "WARN [$label] $f ($warn)"
			printf '%s\n' "$kept" | head -6
			warn_total=$((warn_total + warn))
		fi
	done
	echo "== $label: ${#SOURCES[@]} files, $warn_total warning(s) =="
	return $fail
}

rc=0

echo "### METAL enabled (DARLING_METAL_ENABLED=1)"
run enabled -DDARLING_METAL_ENABLED=1 || rc=1

echo
echo "### METAL disabled (32-bit stub build)"
run disabled -UDARLING_METAL_ENABLED || rc=1

echo
echo "### negative control: the real flags with no substitution, so the installed"
echo "### snapshot wins. This MUST fail, otherwise the hoist is not load-bearing."
if clang "${RAW[@]}" -DDARLING_METAL_ENABLED=1 -fsyntax-only \
       "$DM/src/Metal/MTLSamplerDescriptor.mm" > "$WORK/nohoist.log" 2>&1; then
	echo "NEGATIVE CONTROL FAILED: the check passes without the hoist, so it is not"
	echo "  exercising the clone. Do not trust the results above."
	rc=1
else
	echo "negative control OK: without the hoist the compile fails, so the hoist is load-bearing."
	grep -m3 -E 'error:' "$WORK/nohoist.log" | sed 's/^/  /'
fi

echo
if [ $rc -eq 0 ]; then echo "SYNTAX-CHECK: PASS"; else echo "SYNTAX-CHECK: FAIL"; fi
exit $rc

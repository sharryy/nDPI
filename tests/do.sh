#!/bin/sh

cd "$(dirname "${0}")"

FUZZY_TESTING_ENABLED=0

GCRYPT_ENABLED=1
GCRYPT_PCAPS="gquic.pcap quic-23.pcap quic-24.pcap quic-27.pcap quic-28.pcap quic-29.pcap quic-mvfst-22.pcap quic-mvfst-27.pcapng quic-mvfst-exp.pcap quic_q50.pcap quic_t50.pcap quic_t51.pcap quic_0RTT.pcap quic_interop_V.pcapng quic-33.pcapng doq.pcapng doq_adguard.pcapng dlt_ppp.pcap os_detected.pcapng"
READER="../example/ndpiReader -p ../example/protos.txt -c ../example/categories.txt -r ../example/risky_domains.txt -j ../example/ja3_fingerprints.csv -S ../example/sha1_fingerprints.csv"

RC=0
PCAPS=`cd pcap; /bin/ls *.pcap *.pcapng`

if [ ! -x "../example/ndpiReader" ]; then
  echo "$0: Missing $(realpath ../example/ndpiReader)"
  echo "$0: Run ./configure and make first"
  exit 1
fi

fuzzy_testing() {
    if [ -f ../fuzz/fuzz_ndpi_reader ]; then
	../fuzz/fuzz_ndpi_reader -max_total_time="${MAX_TOTAL_TIME:-592}" -print_pcs=1 -workers="${FUZZY_WORKERS:-0}" -jobs="${FUZZY_JOBS:-0}" pcap/
    fi
}

build_results() {
    for f in $PCAPS; do
	#echo $f
	# create result files if not present
	if [ ! -f result/$f.out ]; then
	    CMD="$READER -q -t -i pcap/$f -w result/$f.out -v 2"
	    $CMD
	fi
    done
}

check_results() {
	for f in $PCAPS; do
	    if [ -n "$*" ]; then
	    	SKIP_PCAP=1
		for i in $* ; do [ "$f" = "$i" ] && SKIP_PCAP=0 && break ; done
		[ $SKIP_PCAP = 1 ] && continue
	    fi
	    SKIP_PCAP=0
	    if [ $GCRYPT_ENABLED -eq 0 ]; then
	      for g in $GCRYPT_PCAPS; do
	        if [ $f = $g ]; then
	          SKIP_PCAP=1
	          break
	        fi
	      done
	    fi
	    if [ $SKIP_PCAP -eq 1 ]; then
	        printf "%-32s\tSKIPPED\n" "$f"
	        continue
	    fi

	if [ -f result/$f.out ]; then
	    CMD="$READER -q -t -i pcap/$f -w /tmp/reader.out -v 2"
	    $CMD
	    NUM_DIFF=`diff result/$f.out /tmp/reader.out | wc -l`

	    if [ $NUM_DIFF -eq 0 ]; then
		printf "%-32s\tOK\n" "$f"
	    else
		printf "%-32s\tERROR\n" "$f"
		echo "$CMD [old vs new]"
		diff result/$f.out /tmp/reader.out
		RC=1
	    fi

	    /bin/rm /tmp/reader.out
	fi
    done
}

if [ $FUZZY_TESTING_ENABLED -eq 1 ]; then
    fuzzy_testing
fi
build_results
check_results $*

exit $RC

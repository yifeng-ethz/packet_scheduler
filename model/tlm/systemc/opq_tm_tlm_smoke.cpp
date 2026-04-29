#include <systemc>

#include <cstdint>
#include <deque>
#include <iostream>
#include <string>

struct Hit {
  int lane = 0;
  int frame = 0;
  int subheader = 0;
  int index = 0;
  std::uint64_t timestamp = 0;
};

SC_MODULE(PacketSchedulerTlmSmoke) {
  sc_core::sc_in<bool> clk{"clk"};
  std::deque<Hit> ingress_q[4];
  std::deque<Hit> egress_q;

  SC_CTOR(PacketSchedulerTlmSmoke) {
    SC_THREAD(run);
  }

  void run() {
    for (int lane = 0; lane < 4; ++lane) {
      for (int hit = 0; hit < 8; ++hit) {
        ingress_q[lane].push_back(Hit{lane, 0, hit / 2, hit, std::uint64_t(hit / 2) * 16});
      }
    }

    bool active = true;
    while (active) {
      active = false;
      for (int lane = 0; lane < 4; ++lane) {
        if (!ingress_q[lane].empty()) {
          active = true;
          egress_q.push_back(ingress_q[lane].front());
          ingress_q[lane].pop_front();
          wait(clk.posedge_event());
        }
      }
    }

    std::cout << "SYSTEMC_TLM_SMOKE_RESULT offered=32 delivered=" << egress_q.size()
              << " controlled_loss=0 asserted_loss=0 inferred_loss="
              << (32 - static_cast<int>(egress_q.size())) << std::endl;
    sc_core::sc_stop();
  }
};

#ifdef MTI_SYSTEMC
SC_MODULE(top) {
  sc_core::sc_clock clk{"clk", sc_core::sc_time(4, sc_core::SC_NS)};
  PacketSchedulerTlmSmoke tlm{"tlm"};

  SC_CTOR(top) {
    tlm.clk(clk);
  }
};

SC_MODULE_EXPORT(top);
#else
int sc_main(int, char**) {
  sc_core::sc_clock clk{"clk", sc_core::sc_time(4, sc_core::SC_NS)};
  PacketSchedulerTlmSmoke tlm{"tlm"};
  tlm.clk(clk);
  sc_core::sc_start();
  return 0;
}
#endif

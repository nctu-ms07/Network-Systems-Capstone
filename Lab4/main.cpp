#include <pcap.h>
#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <vector>
#include <string>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <netinet/ip.h>

using namespace std;

char errbuf[PCAP_ERRBUF_SIZE];

int main() {
  pcap_if_t *device;
  if (pcap_findalldevs(&device, errbuf) == -1) {
    cout << "pcap_findalldevs(): " << errbuf << '\n';
    exit(EXIT_FAILURE);
  }

  vector<char *> devices;
  while (device) {
    cout << devices.size() << " Name: " << device->name << '\n';
    devices.emplace_back(device->name);
    device = device->next;
  }

  int input;
  cout << "Insert a number to select interface:" << '\n';
  cin >> input;

  pcap_t *handle = pcap_open_live(devices[input], BUFSIZ, 1, 0, errbuf);
  if (handle == NULL) {
    cout << "pcap_open_live(): " << errbuf << '\n';
    exit(EXIT_FAILURE);
  }
  cout << "Start listening at $" << devices[input] << '\n';

  string filter_exp;
  cout << "Insert BPF filter expression:" << '\n';
  getline(cin.ignore(), filter_exp);
  if (!filter_exp.empty()) {
    filter_exp += " && ";
  }
  filter_exp += "dst host 140.113.0.1";

  bpf_program filter;
  if (pcap_compile(handle, &filter, filter_exp.c_str(), 0, PCAP_NETMASK_UNKNOWN) == PCAP_ERROR) {
    cout << "pcap_compile() " << pcap_geterr(handle) << '\n';
    exit(EXIT_FAILURE);
  }

  if (pcap_setfilter(handle, &filter) == PCAP_ERROR) {
    cout << "pcap_setfilter() " << pcap_geterr(handle) << '\n';
    exit(EXIT_FAILURE);
  }
  cout << "filter: " << filter_exp << "\n\n";

  system("ip link add br1 type bridge");
  system("ip link set BRGrGWr master br1");
  system("ip link set br1 up");

  int packet_num = 1;
  pcap_pkthdr pkt_hdr;
  while (true) {
    const u_char *pkt_cursor = pcap_next(handle, &pkt_hdr);
    cout << "Packet Num [" << dec << packet_num++ << "]\n";

    for (int i = 0; i < pkt_hdr.len; i++) {
      cout << setw(2) << setfill('0') << hex << +pkt_cursor[i] << ' ';
      if ((i + 1) % 16 == 0 || (i + 1) == pkt_hdr.len) {
        cout << '\n';
      }
    }
    cout << '\n';

    ether_header *eth_hdr = (struct ether_header *) pkt_cursor;
    pkt_cursor += sizeof(struct ether_header);
    cout << "Outer Destination MAC:  ";
    for (int i = 0; i < ETH_ALEN; i++) {
      cout << setw(2) << setfill('0') << hex << +eth_hdr->ether_dhost[i] << ':';
    }
    cout << "\b \b\n";
    cout << "Outer Source MAC:  ";
    for (int i = 0; i < ETH_ALEN; i++) {
      cout << setw(2) << setfill('0') << hex << +eth_hdr->ether_shost[i] << ':';
    }
    cout << "\b \b\n";
    cout << "Outer Ether Type: " << setw(4) << setfill('0') << hex << ntohs(eth_hdr->ether_type) << '\n';

    ip *ip_hdr = (struct ip *) pkt_cursor;
    pkt_cursor += sizeof(struct ip);
    string srcIP = inet_ntoa(ip_hdr->ip_src);
    cout << "Outer Source IP: " << srcIP << '\n';
    cout << "Outer Destination IP: " << inet_ntoa(ip_hdr->ip_dst) << '\n';

    if (+ip_hdr->ip_p == 47) {
      cout << "Next Layer Protocol: GRE\n\n";
      pkt_cursor += 2; // Note: Ignore GRE header flag and version (assuming it's 0x0000)
      cout << "Protocol: " << setw(2) << setfill('0') << hex << +pkt_cursor[0] << +pkt_cursor[1] << '\n';
      pkt_cursor += 2;

      eth_hdr = (struct ether_header *) pkt_cursor;
      pkt_cursor += sizeof(struct ether_header);
      cout << "Inner Destination MAC:  ";
      for (int i = 0; i < ETH_ALEN; i++) {
        cout << setw(2) << setfill('0') << hex << +eth_hdr->ether_dhost[i] << ':';
      }
      cout << "\b \b\n";
      cout << "Inner Source MAC:  ";
      for (int i = 0; i < ETH_ALEN; i++) {
        cout << setw(2) << setfill('0') << hex << +eth_hdr->ether_shost[i] << ':';
      }
      cout << "\b \b\n";
      cout << "Inner Ether Type: " << setw(4) << setfill('0') << hex << ntohs(eth_hdr->ether_type) << '\n';

      string dev_name = "GRETAP" + to_string(packet_num);
      system(("ip link add " + dev_name + " type gretap remote " += srcIP + " local 140.113.0.1").c_str());
      system(("ip link set " + dev_name + " up").c_str());
      system(("ip link set " + dev_name + " master br1").c_str());

      filter_exp += "&& src host not " + srcIP;
      if (pcap_compile(handle, &filter, filter_exp.c_str(), 0, PCAP_NETMASK_UNKNOWN) == PCAP_ERROR) {
        cout << "pcap_compile() " << pcap_geterr(handle) << '\n';
        exit(EXIT_FAILURE);
      }

      if (pcap_setfilter(handle, &filter) == PCAP_ERROR) {
        cout << "pcap_setfilter() " << pcap_geterr(handle) << '\n';
        exit(EXIT_FAILURE);
      }
    }
    cout << '\n';
  }
  return 0;
}
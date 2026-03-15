# router-dos-tool
# DISCLAIMER  FOR EDUCATIONAL &amp; AUTHORIZED TESTING ONLY. Unauthorized use is ILLEGAL (violates CFAA, Computer Misuse Act). Offenders face imprisonment, fines, and civil liability. Use ONLY on YOUR systems or with WRITTEN permission. Authors assume NO LIABILITY for misuse/damages. By using, you accept FULL responsibility. When in doubt, DON'T USE.

# Router/Host DoS Testing Tool

[![Educational Purpose Only](https://img.shields.io/badge/Purpose-Educational%20Only-red)](https://github.com/)
[![Bash](https://img.shields.io/badge/Language-Bash-green)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

> ⚠️ **WARNING: This tool is for EDUCATIONAL and AUTHORIZED TESTING purposes ONLY!**  
> Unauthorized use against systems you don't own or don't have permission to test is ILLEGAL.  
> The author is not responsible for any misuse or damage caused by this tool.

## 📋 Description

A comprehensive network stress testing tool designed for security professionals and network administrators to test the resilience of routers and hosts against various Denial of Service (DoS) attacks. This tool combines multiple attack methodologies to simulate real-world attack scenarios.

## 🎯 Features

### 🔹 TCP Flooding Attacks
- SYN Flood (specific port or all open ports)
- ACK Flood (firewall bypass)
- FIN/RST Flood (connection disruption)
- XMAS Tree Attack (all flags set)

### 🔹 UDP Flooding Attacks
- UDP Flood (specific or random ports)
- DNS Amplification (if target is DNS server)
- NTP Amplification (if target is NTP server)

### 🔹 ICMP Attacks
- ICMP Echo Flood (Ping flood)
- ICMP Fragmentation Attack
- ICMP Smurf Attack (broadcast)

### 🔹 Layer 2 Attacks
- ARP Flood (target specific)
- MAC Flood (switch CAM table)

### 🔹 DHCP Attacks (if target is DHCP server)
- DHCP Discover Flood
- DHCP Release Attack
- DHCP Starvation

### 🔹 Combination Attacks
- SYN + UDP simultaneous flood
- Multi-port SYN flood
- Full nuclear option (everything at once)

### 🔹 Monitoring Features
- Real-time host status monitoring
- Traffic capture to/from target
- Automatic port scanning
- OS detection

## 📋 Prerequisites

- **Operating System**: Linux (Ubuntu/Debian/Kali recommended)
- **Permissions**: Root/sudo access
- **Required Packages** (automatically installed):
  - hping3
  - nmap
  - tcpdump
  - arping
  - dhcpig (optional)
  - dhcping (optional)
  - python3-scapy (optional)

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/router-dos-tool.git

# Navigate to directory
cd router-dos-tool

# Make the script executable
chmod +x dos_tool.sh

# Run the tool (must be root)
sudo ./dos_tool.sh
```

## 💻 Usage

1. **Run as root**: `sudo ./dos_tool.sh`
2. **Enter target**: IP address or hostname
3. **Choose attack type** from the interactive menu
4. **Monitor results** in real-time
5. **Check logs** in the `attack_logs/` directory

### Example:
```bash
sudo ./dos_tool.sh
# Enter target: 192.168.1.1
# Select option: 1a (SYN Flood)
# Enter port: 80
# Press Ctrl+C to stop
```

## 📁 Project Structure

```
router-dos-tool/
├── dos_tool.sh           # Main script
├── README.md             # This file
├── LICENSE               # MIT License
├── .gitignore            # Git ignore file
└── attack_logs/          # Attack logs directory
    ├── syn_flood_*.log
    ├── udp_flood_*.log
    └── ...
```

## ⚙️ Configuration

The script automatically detects:
- Network interface
- Target MAC address
- Open ports (via nmap)
- Operating system

Configuration variables at the top of the script:
```bash
LOG_DIR="./attack_logs"   # Log directory
INTERFACE="auto"          # Network interface
```

## 📊 Logging

All attacks are logged in the `attack_logs/` directory with timestamps:
- `syn_flood_port80_20240101_120000.log`
- `udp_flood_random_20240101_120005.log`
- `arp_flood_20240101_120010.log`

## 🔒 Legal & Ethical Use

This tool should ONLY be used:

✅ On your own devices/networks  
✅ On systems you have explicit written permission to test  
✅ For educational purposes in controlled environments  
✅ By security professionals during authorized penetration tests  

❌ NEVER use against:
- Public networks/servers
- Systems you don't own
- Without proper authorization
- For any illegal purpose

## ⚠️ Disclaimer

This tool is provided for educational and ethical testing purposes only. The authors and contributors are not responsible for any misuse or damage caused by this program. Users are solely responsible for complying with all applicable local, state, and federal laws.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📧 Contact

Project Link: [https://github.com/talha116-dev/router-dos-tool](https://github.com/YOUR-USERNAME/router-dos-tool)

## 🙏 Acknowledgments

- hping3 developers
- nmap project
- Scapy community
- All ethical security researchers

---

**Remember:** With great power comes great responsibility! 🕷️

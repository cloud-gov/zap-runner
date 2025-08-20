#!/usr/bin/env python3
"""
Collect and analyze ZAP scan metrics for monitoring and reporting.
This script processes scan results to generate metrics for dashboards and alerting.
"""

import json
import yaml
import sys
import os
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict
import argparse


class ZAPMetricsCollector:
    """Collect and analyze metrics from ZAP scan results."""
    
    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.metrics = {
            'timestamp': datetime.utcnow().isoformat(),
            'contexts': {},
            'summary': {
                'total_urls': 0,
                'total_alerts': 0,
                'high_risk': 0,
                'medium_risk': 0,
                'low_risk': 0,
                'info': 0,
                'unique_vulnerabilities': set(),
                'scan_duration': 0
            },
            'trends': {
                'daily': [],
                'weekly': [],
                'monthly': []
            }
        }
    
    def collect_xml_metrics(self, xml_file):
        """Extract metrics from XML report."""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            context_metrics = {
                'alerts': [],
                'risk_distribution': defaultdict(int),
                'confidence_distribution': defaultdict(int),
                'urls_scanned': 0
            }
            
            # Count URLs
            for site in root.findall('.//site'):
                context_metrics['urls_scanned'] += 1
                
                # Process alerts
                for alert in site.findall('.//alertitem'):
                    risk = alert.find('riskcode')
                    confidence = alert.find('confidence')
                    name = alert.find('name')
                    
                    if risk is not None:
                        risk_level = int(risk.text)
                        if risk_level == 3:
                            context_metrics['risk_distribution']['high'] += 1
                            self.metrics['summary']['high_risk'] += 1
                        elif risk_level == 2:
                            context_metrics['risk_distribution']['medium'] += 1
                            self.metrics['summary']['medium_risk'] += 1
                        elif risk_level == 1:
                            context_metrics['risk_distribution']['low'] += 1
                            self.metrics['summary']['low_risk'] += 1
                        else:
                            context_metrics['risk_distribution']['info'] += 1
                            self.metrics['summary']['info'] += 1
                    
                    if confidence is not None:
                        conf_level = int(confidence.text)
                        if conf_level == 3:
                            context_metrics['confidence_distribution']['high'] += 1
                        elif conf_level == 2:
                            context_metrics['confidence_distribution']['medium'] += 1
                        elif conf_level == 1:
                            context_metrics['confidence_distribution']['low'] += 1
                    
                    if name is not None:
                        self.metrics['summary']['unique_vulnerabilities'].add(name.text)
                        context_metrics['alerts'].append({
                            'name': name.text,
                            'risk': risk.text if risk is not None else '0',
                            'confidence': confidence.text if confidence is not None else '0'
                        })
            
            self.metrics['summary']['total_alerts'] += len(context_metrics['alerts'])
            self.metrics['summary']['total_urls'] += context_metrics['urls_scanned']
            
            return context_metrics
            
        except Exception as e:
            print(f"Error processing XML file {xml_file}: {e}")
            return None
    
    def collect_json_metrics(self, json_file):
        """Extract additional metrics from JSON report."""
        try:
            with open(json_file) as f:
                data = json.load(f)
            
            # Extract scan metadata if available
            metadata = {
                'generated': data.get('@generated', ''),
                'version': data.get('@version', ''),
                'scan_time': None
            }
            
            # Try to calculate scan duration
            if 'site' in data:
                for site in data['site']:
                    if '@start' in site and '@end' in site:
                        start = datetime.fromisoformat(site['@start'])
                        end = datetime.fromisoformat(site['@end'])
                        duration = (end - start).total_seconds()
                        metadata['scan_time'] = duration
                        self.metrics['summary']['scan_duration'] += duration
            
            return metadata
            
        except Exception as e:
            print(f"Error processing JSON file {json_file}: {e}")
            return None
    
    def analyze_trends(self):
        """Analyze trends from historical data."""
        # This would typically read from a database or historical files
        # For now, we'll create placeholder trend data
        
        self.metrics['trends']['daily'] = {
            'dates': [],
            'high_risk': [],
            'medium_risk': [],
            'low_risk': []
        }
        
        # Generate last 7 days of mock trend data
        for i in range(7):
            date = (datetime.utcnow() - timedelta(days=i)).strftime('%Y-%m-%d')
            self.metrics['trends']['daily']['dates'].append(date)
            # In production, these would be actual historical values
            self.metrics['trends']['daily']['high_risk'].append(0)
            self.metrics['trends']['daily']['medium_risk'].append(0)
            self.metrics['trends']['daily']['low_risk'].append(0)
    
    def generate_prometheus_metrics(self):
        """Generate metrics in Prometheus format."""
        prometheus_metrics = []
        
        # Summary metrics
        prometheus_metrics.append(f'zap_scan_total_urls {self.metrics["summary"]["total_urls"]}')
        prometheus_metrics.append(f'zap_scan_total_alerts {self.metrics["summary"]["total_alerts"]}')
        prometheus_metrics.append(f'zap_scan_high_risk_count {self.metrics["summary"]["high_risk"]}')
        prometheus_metrics.append(f'zap_scan_medium_risk_count {self.metrics["summary"]["medium_risk"]}')
        prometheus_metrics.append(f'zap_scan_low_risk_count {self.metrics["summary"]["low_risk"]}')
        prometheus_metrics.append(f'zap_scan_info_count {self.metrics["summary"]["info"]}')
        prometheus_metrics.append(f'zap_scan_unique_vulnerabilities {len(self.metrics["summary"]["unique_vulnerabilities"])}')
        prometheus_metrics.append(f'zap_scan_duration_seconds {self.metrics["summary"]["scan_duration"]}')
        
        # Per-context metrics
        for context, data in self.metrics['contexts'].items():
            if 'risk_distribution' in data:
                for risk, count in data['risk_distribution'].items():
                    prometheus_metrics.append(f'zap_context_risk_count{{context="{context}",risk="{risk}"}} {count}')
        
        return '\n'.join(prometheus_metrics)
    
    def generate_grafana_dashboard(self):
        """Generate Grafana dashboard JSON."""
        dashboard = {
            "dashboard": {
                "title": "ZAP Security Scanning Metrics",
                "panels": [
                    {
                        "title": "Total Vulnerabilities by Risk",
                        "type": "graph",
                        "targets": [
                            {"expr": "zap_scan_high_risk_count", "legendFormat": "High Risk"},
                            {"expr": "zap_scan_medium_risk_count", "legendFormat": "Medium Risk"},
                            {"expr": "zap_scan_low_risk_count", "legendFormat": "Low Risk"}
                        ]
                    },
                    {
                        "title": "Scan Coverage",
                        "type": "stat",
                        "targets": [
                            {"expr": "zap_scan_total_urls", "legendFormat": "URLs Scanned"}
                        ]
                    },
                    {
                        "title": "Scan Duration",
                        "type": "gauge",
                        "targets": [
                            {"expr": "zap_scan_duration_seconds / 60", "legendFormat": "Minutes"}
                        ]
                    },
                    {
                        "title": "Unique Vulnerabilities",
                        "type": "stat",
                        "targets": [
                            {"expr": "zap_scan_unique_vulnerabilities", "legendFormat": "Unique Issues"}
                        ]
                    }
                ]
            }
        }
        return json.dumps(dashboard, indent=2)
    
    def process_all_results(self):
        """Process all scan results in the directory."""
        # Process XML files
        for xml_file in self.results_dir.glob('**/*.xml'):
            context = xml_file.parent.name
            metrics = self.collect_xml_metrics(xml_file)
            if metrics:
                self.metrics['contexts'][context] = metrics
        
        # Process JSON files for additional metadata
        for json_file in self.results_dir.glob('**/*.json'):
            if 'sarif' not in str(json_file):  # Skip SARIF files
                metadata = self.collect_json_metrics(json_file)
                if metadata:
                    context = json_file.parent.name
                    if context in self.metrics['contexts']:
                        self.metrics['contexts'][context]['metadata'] = metadata
        
        # Convert set to list for JSON serialization
        self.metrics['summary']['unique_vulnerabilities'] = list(
            self.metrics['summary']['unique_vulnerabilities']
        )
        
        # Analyze trends
        self.analyze_trends()
    
    def save_metrics(self, output_dir):
        """Save metrics to various formats."""
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save JSON metrics
        with open(output_path / 'metrics.json', 'w') as f:
            json.dump(self.metrics, f, indent=2)
        
        # Save Prometheus metrics
        with open(output_path / 'metrics.prom', 'w') as f:
            f.write(self.generate_prometheus_metrics())
        
        # Save Grafana dashboard
        with open(output_path / 'dashboard.json', 'w') as f:
            f.write(self.generate_grafana_dashboard())
        
        # Generate summary report
        self.generate_summary_report(output_path / 'summary.txt')
    
    def generate_summary_report(self, output_file):
        """Generate human-readable summary report."""
        with open(output_file, 'w') as f:
            f.write("ZAP Scan Metrics Summary\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Timestamp: {self.metrics['timestamp']}\n\n")
            
            f.write("Overall Statistics:\n")
            f.write("-" * 20 + "\n")
            f.write(f"Total URLs Scanned: {self.metrics['summary']['total_urls']}\n")
            f.write(f"Total Alerts: {self.metrics['summary']['total_alerts']}\n")
            f.write(f"High Risk: {self.metrics['summary']['high_risk']}\n")
            f.write(f"Medium Risk: {self.metrics['summary']['medium_risk']}\n")
            f.write(f"Low Risk: {self.metrics['summary']['low_risk']}\n")
            f.write(f"Informational: {self.metrics['summary']['info']}\n")
            f.write(f"Unique Vulnerabilities: {len(self.metrics['summary']['unique_vulnerabilities'])}\n")
            f.write(f"Total Scan Duration: {self.metrics['summary']['scan_duration']:.2f} seconds\n\n")
            
            f.write("Per-Context Breakdown:\n")
            f.write("-" * 20 + "\n")
            for context, data in self.metrics['contexts'].items():
                f.write(f"\n{context}:\n")
                f.write(f"  URLs: {data.get('urls_scanned', 0)}\n")
                f.write(f"  Alerts: {len(data.get('alerts', []))}\n")
                if 'risk_distribution' in data:
                    f.write("  Risk Distribution:\n")
                    for risk, count in data['risk_distribution'].items():
                        f.write(f"    {risk}: {count}\n")


def main():
    parser = argparse.ArgumentParser(
        description='Collect and analyze ZAP scan metrics'
    )
    parser.add_argument(
        '--results-dir',
        required=True,
        help='Directory containing scan results'
    )
    parser.add_argument(
        '--output-dir',
        default='metrics',
        help='Directory to save metrics (default: metrics)'
    )
    parser.add_argument(
        '--format',
        choices=['all', 'json', 'prometheus', 'grafana'],
        default='all',
        help='Output format (default: all)'
    )
    
    args = parser.parse_args()
    
    # Initialize collector
    collector = ZAPMetricsCollector(args.results_dir)
    
    # Process results
    print("Processing scan results...")
    collector.process_all_results()
    
    # Save metrics
    print(f"Saving metrics to {args.output_dir}...")
    collector.save_metrics(args.output_dir)
    
    # Print summary
    print("\nMetrics Summary:")
    print(f"  Total URLs: {collector.metrics['summary']['total_urls']}")
    print(f"  Total Alerts: {collector.metrics['summary']['total_alerts']}")
    print(f"  High Risk: {collector.metrics['summary']['high_risk']}")
    print(f"  Medium Risk: {collector.metrics['summary']['medium_risk']}")
    print(f"  Low Risk: {collector.metrics['summary']['low_risk']}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
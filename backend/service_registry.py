#!/usr/bin/env python3
"""
Service Registry and Health Monitoring for Tessera Backend
Provides service discovery, health monitoring, and load balancing
"""

import asyncio
import aiohttp
import json
import time
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum
from pathlib import Path
import structlog

logger = structlog.get_logger(__name__)


class ServiceStatus(Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"


@dataclass
class ServiceInfo:
    """Service information and metadata"""
    name: str
    host: str
    port: int
    protocol: str = "http"
    health_endpoint: str = "/health"
    version: str = "1.0.0"
    tags: List[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.tags is None:
            self.tags = []
        if self.metadata is None:
            self.metadata = {}
    
    @property
    def url(self) -> str:
        return f"{self.protocol}://{self.host}:{self.port}"
    
    @property
    def health_url(self) -> str:
        return f"{self.url}{self.health_endpoint}"


@dataclass
class ServiceHealth:
    """Service health status and metrics"""
    service_name: str
    status: ServiceStatus
    last_check: float
    response_time_ms: float
    error_message: Optional[str] = None
    consecutive_failures: int = 0
    uptime_percentage: float = 100.0
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class ServiceRegistry:
    """Service registry with health monitoring and load balancing"""
    
    def __init__(self, check_interval: int = 30, timeout: int = 10):
        self.services: Dict[str, ServiceInfo] = {}
        self.health_status: Dict[str, ServiceHealth] = {}
        self.check_interval = check_interval
        self.timeout = timeout
        self._monitoring_task: Optional[asyncio.Task] = None
        self._session: Optional[aiohttp.ClientSession] = None
        
        # Load balancing state
        self._round_robin_counters: Dict[str, int] = {}
        
        logger.info("Service registry initialized", 
                   check_interval=check_interval, timeout=timeout)
    
    async def start(self):
        """Start the service registry and health monitoring"""
        self._session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=self.timeout)
        )
        
        # Start health monitoring task
        self._monitoring_task = asyncio.create_task(self._health_monitor_loop())
        
        logger.info("Service registry started")
    
    async def stop(self):
        """Stop the service registry"""
        if self._monitoring_task:
            self._monitoring_task.cancel()
            try:
                await self._monitoring_task
            except asyncio.CancelledError:
                pass
        
        if self._session:
            await self._session.close()
        
        logger.info("Service registry stopped")
    
    def register_service(self, service: ServiceInfo):
        """Register a new service"""
        self.services[service.name] = service
        self.health_status[service.name] = ServiceHealth(
            service_name=service.name,
            status=ServiceStatus.UNKNOWN,
            last_check=0,
            response_time_ms=0
        )
        self._round_robin_counters[service.name] = 0
        
        logger.info("Service registered", service_name=service.name, 
                   url=service.url)
    
    def unregister_service(self, service_name: str):
        """Unregister a service"""
        if service_name in self.services:
            del self.services[service_name]
            del self.health_status[service_name]
            if service_name in self._round_robin_counters:
                del self._round_robin_counters[service_name]
            
            logger.info("Service unregistered", service_name=service_name)
    
    def get_service(self, service_name: str) -> Optional[ServiceInfo]:
        """Get service information"""
        return self.services.get(service_name)
    
    def get_healthy_services(self, service_type: Optional[str] = None) -> List[ServiceInfo]:
        """Get all healthy services, optionally filtered by type"""
        healthy_services = []
        
        for service_name, service in self.services.items():
            health = self.health_status.get(service_name)
            if health and health.status == ServiceStatus.HEALTHY:
                if service_type is None or service_type in service.tags:
                    healthy_services.append(service)
        
        return healthy_services
    
    def get_service_for_load_balancing(self, service_type: str) -> Optional[ServiceInfo]:
        """Get a service using round-robin load balancing"""
        healthy_services = self.get_healthy_services(service_type)
        
        if not healthy_services:
            return None
        
        # Round-robin selection
        counter_key = f"lb_{service_type}"
        if counter_key not in self._round_robin_counters:
            self._round_robin_counters[counter_key] = 0
        
        index = self._round_robin_counters[counter_key] % len(healthy_services)
        self._round_robin_counters[counter_key] += 1
        
        selected_service = healthy_services[index]
        logger.debug("Service selected for load balancing", 
                    service_name=selected_service.name, 
                    service_type=service_type)
        
        return selected_service
    
    def get_service_health(self, service_name: str) -> Optional[ServiceHealth]:
        """Get service health status"""
        return self.health_status.get(service_name)
    
    def get_all_health_status(self) -> Dict[str, ServiceHealth]:
        """Get health status for all services"""
        return self.health_status.copy()
    
    async def check_service_health(self, service_name: str) -> ServiceHealth:
        """Check health of a specific service"""
        service = self.services.get(service_name)
        if not service:
            return ServiceHealth(
                service_name=service_name,
                status=ServiceStatus.UNKNOWN,
                last_check=time.time(),
                response_time_ms=0,
                error_message="Service not registered"
            )
        
        start_time = time.time()
        
        try:
            async with self._session.get(service.health_url) as response:
                response_time_ms = (time.time() - start_time) * 1000
                
                if response.status == 200:
                    # Try to parse response for additional metadata
                    try:
                        health_data = await response.json()
                        metadata = health_data if isinstance(health_data, dict) else {}
                    except:
                        metadata = {}
                    
                    # Update health status
                    health = ServiceHealth(
                        service_name=service_name,
                        status=ServiceStatus.HEALTHY,
                        last_check=time.time(),
                        response_time_ms=response_time_ms,
                        consecutive_failures=0,
                        metadata=metadata
                    )
                    
                    # Calculate uptime percentage
                    old_health = self.health_status.get(service_name)
                    if old_health:
                        health.uptime_percentage = old_health.uptime_percentage
                    
                else:
                    health = ServiceHealth(
                        service_name=service_name,
                        status=ServiceStatus.DEGRADED,
                        last_check=time.time(),
                        response_time_ms=response_time_ms,
                        error_message=f"HTTP {response.status}",
                        consecutive_failures=self.health_status.get(service_name, ServiceHealth(service_name, ServiceStatus.UNKNOWN, 0, 0)).consecutive_failures + 1
                    )
        
        except asyncio.TimeoutError:
            health = ServiceHealth(
                service_name=service_name,
                status=ServiceStatus.UNHEALTHY,
                last_check=time.time(),
                response_time_ms=self.timeout * 1000,
                error_message="Health check timeout",
                consecutive_failures=self.health_status.get(service_name, ServiceHealth(service_name, ServiceStatus.UNKNOWN, 0, 0)).consecutive_failures + 1
            )
        
        except Exception as e:
            health = ServiceHealth(
                service_name=service_name,
                status=ServiceStatus.UNHEALTHY,
                last_check=time.time(),
                response_time_ms=0,
                error_message=str(e),
                consecutive_failures=self.health_status.get(service_name, ServiceHealth(service_name, ServiceStatus.UNKNOWN, 0, 0)).consecutive_failures + 1
            )
        
        # Update uptime percentage
        old_health = self.health_status.get(service_name)
        if old_health and old_health.last_check > 0:
            # Simple uptime calculation based on recent checks
            if health.status == ServiceStatus.HEALTHY:
                health.uptime_percentage = min(100.0, old_health.uptime_percentage + 1.0)
            else:
                health.uptime_percentage = max(0.0, old_health.uptime_percentage - 2.0)
        
        self.health_status[service_name] = health
        
        logger.debug("Service health checked", 
                    service_name=service_name,
                    status=health.status.value,
                    response_time_ms=health.response_time_ms)
        
        return health
    
    async def _health_monitor_loop(self):
        """Background task to monitor service health"""
        while True:
            try:
                # Check all registered services
                tasks = []
                for service_name in self.services.keys():
                    task = asyncio.create_task(self.check_service_health(service_name))
                    tasks.append(task)
                
                if tasks:
                    await asyncio.gather(*tasks, return_exceptions=True)
                
                # Log overall health summary
                healthy_count = sum(1 for h in self.health_status.values() 
                                  if h.status == ServiceStatus.HEALTHY)
                total_count = len(self.health_status)
                
                logger.info("Health monitoring cycle completed",
                           healthy_services=healthy_count,
                           total_services=total_count)
                
                await asyncio.sleep(self.check_interval)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("Error in health monitoring loop", error=str(e))
                await asyncio.sleep(5)  # Short delay before retrying
    
    def export_config(self, file_path: str):
        """Export service registry configuration to JSON file"""
        config = {
            "services": {name: asdict(service) for name, service in self.services.items()},
            "health_status": {name: asdict(health) for name, health in self.health_status.items()}
        }
        
        with open(file_path, 'w') as f:
            json.dump(config, f, indent=2, default=str)
        
        logger.info("Service registry configuration exported", file_path=file_path)
    
    def import_config(self, file_path: str):
        """Import service registry configuration from JSON file"""
        try:
            with open(file_path, 'r') as f:
                config = json.load(f)
            
            # Import services
            for name, service_data in config.get("services", {}).items():
                service = ServiceInfo(**service_data)
                self.register_service(service)
            
            logger.info("Service registry configuration imported", 
                       file_path=file_path, 
                       services_count=len(self.services))
        
        except Exception as e:
            logger.error("Failed to import service registry configuration", 
                        file_path=file_path, error=str(e))


# Global service registry instance
_service_registry: Optional[ServiceRegistry] = None


def get_service_registry() -> ServiceRegistry:
    """Get the global service registry instance"""
    global _service_registry
    if _service_registry is None:
        _service_registry = ServiceRegistry()
    return _service_registry


async def initialize_tessera_services():
    """Initialize Tessera service registry with default services"""
    registry = get_service_registry()
    await registry.start()
    
    # Check Zig acceleration status
    zig_available = check_zig_acceleration()
    
    # Register Tessera services
    services = [
        ServiceInfo(
            name="perl-api",
            host="127.0.0.1",
            port=3000,
            health_endpoint="/health",
            tags=["api", "gateway", "perl"],
            metadata={
                "language": "perl", 
                "framework": "mojolicious",
                "zig_acceleration": zig_available
            }
        ),
        ServiceInfo(
            name="gemini-service",
            host="127.0.0.1",
            port=8001,
            health_endpoint="/health",
            tags=["ai", "chat", "python"],
            metadata={
                "language": "python", 
                "framework": "fastapi",
                "zig_acceleration": zig_available
            }
        ),
        ServiceInfo(
            name="embedding-service",
            host="127.0.0.1",
            port=8002,
            health_endpoint="/health",
            tags=["ai", "embedding", "python"],
            metadata={
                "language": "python", 
                "framework": "fastapi",
                "zig_acceleration": zig_available,
                "performance_critical": True
            }
        ),
        ServiceInfo(
            name="data-ingestion-service",
            host="127.0.0.1",
            port=8003,
            health_endpoint="/health",
            tags=["ingestion", "processing", "python"],
            metadata={
                "language": "python", 
                "framework": "fastapi",
                "zig_acceleration": zig_available
            }
        )
    ]
    
    for service in services:
        registry.register_service(service)
    
    logger.info("Tessera services registered in service registry", 
               zig_acceleration=zig_available)
    return registry


def check_zig_acceleration():
    """Check if Zig acceleration libraries are available"""
    import os
    from pathlib import Path
    
    # Check for Zig libraries
    project_root = Path(__file__).parent.parent
    zig_lib_paths = [
        project_root / "zig-backend" / "zig-out" / "lib" / "libtessera_vector_ops.so",
        project_root / "zig-backend" / "zig-out" / "lib" / "libtessera_vector_ops.dylib"
    ]
    
    for lib_path in zig_lib_paths:
        if lib_path.exists():
            logger.info("Zig acceleration libraries found", lib_path=str(lib_path))
            return True
    
    logger.info("Zig acceleration libraries not found, using fallback implementations")
    return False


if __name__ == "__main__":
    async def main():
        # Test the service registry
        registry = await initialize_tessera_services()
        
        # Wait for a few health checks
        await asyncio.sleep(35)
        
        # Print health status
        print("\n=== Service Health Status ===")
        for name, health in registry.get_all_health_status().items():
            print(f"{name}: {health.status.value} "
                  f"({health.response_time_ms:.1f}ms, "
                  f"{health.uptime_percentage:.1f}% uptime)")
        
        # Test load balancing
        print("\n=== Load Balancing Test ===")
        for i in range(5):
            service = registry.get_service_for_load_balancing("python")
            if service:
                print(f"Request {i+1}: {service.name}")
        
        await registry.stop()
    
    asyncio.run(main())

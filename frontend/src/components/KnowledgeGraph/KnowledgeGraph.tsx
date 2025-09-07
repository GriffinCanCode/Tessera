import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import TesseraAPI from '../../services/api';
import type { KnowledgeGraph as KnowledgeGraphType, KnowledgeGraphNode } from '../../types/api';
import type * as d3 from 'd3';

interface GraphNodeData extends KnowledgeGraphNode {
  x: number;
  y: number;
  vx?: number;
  vy?: number;
  fx?: number | null;
  fy?: number | null;
}

interface GraphControlsProps {
  onCenterClick: () => void;
  onZoomIn: () => void;
  onZoomOut: () => void;
  onExport: (format: 'json' | 'svg' | 'png') => void;
  minRelevance: number;
  onMinRelevanceChange: (value: number) => void;
  maxDepth: number;
  onMaxDepthChange: (value: number) => void;
  selectedLayout: string;
  onLayoutChange: (layout: string) => void;
  availableLayouts: string[];
  layoutRecommendations?: Record<string, string[]>;
}

function GraphControls({ 
  onCenterClick, 
  onZoomIn, 
  onZoomOut, 
  onExport,
  minRelevance,
  onMinRelevanceChange,
  maxDepth,
  onMaxDepthChange,
  selectedLayout,
  onLayoutChange,
  availableLayouts,
  layoutRecommendations
}: GraphControlsProps) {
  return (
    <div className="absolute top-4 right-4 z-10 space-y-2">
      {/* Graph Settings Panel */}
      <div className="bg-white/90 backdrop-blur-md rounded-xl border border-white/20 shadow-lg p-4 space-y-4">
        <h3 className="font-semibold text-sm text-slate-800">Graph Settings</h3>
        
        {/* Relevance Filter */}
        <div className="space-y-2">
          <label className="text-xs font-medium text-slate-600">
            Min Relevance: {Math.round(minRelevance * 100)}%
          </label>
          <input
            type="range"
            min="0"
            max="1"
            step="0.05"
            value={minRelevance}
            onChange={(e) => onMinRelevanceChange(Number(e.target.value))}
            className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer
                     slider:bg-gradient-to-r slider:from-purple-500 slider:to-pink-500"
          />
        </div>

        {/* Max Depth */}
        <div className="space-y-2">
          <label className="text-xs font-medium text-slate-600">
            Max Depth: {maxDepth}
          </label>
          <input
            type="range"
            min="1"
            max="5"
            step="1"
            value={maxDepth}
            onChange={(e) => onMaxDepthChange(Number(e.target.value))}
            className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer
                     slider:bg-gradient-to-r slider:from-blue-500 slider:to-teal-500"
          />
        </div>

        {/* Layout Algorithm Selection */}
        <div className="space-y-2">
          <label className="text-xs font-medium text-slate-600">
            Layout Algorithm
          </label>
          <select
            value={selectedLayout}
            onChange={(e) => onLayoutChange(e.target.value)}
            className="w-full px-2 py-1 text-xs bg-white border border-slate-200 rounded-lg
                     focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
          >
            {availableLayouts.map(layout => (
              <option key={layout} value={layout}>
                {layout.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
              </option>
            ))}
          </select>
          
          {/* Show recommendations if available */}
          {layoutRecommendations && (
            <div className="text-xs text-slate-500 mt-1">
              💡 Recommended: {Object.values(layoutRecommendations).flat().slice(0, 2).join(', ')}
            </div>
          )}
        </div>
      </div>

      {/* Control Buttons */}
      <div className="bg-white/90 backdrop-blur-md rounded-xl border border-white/20 shadow-lg p-3">
        <div className="grid grid-cols-2 gap-2 mb-3">
          <button
            onClick={onZoomIn}
            className="flex items-center justify-center w-8 h-8 rounded-lg bg-gradient-to-r from-blue-500 to-purple-500 
                     text-white font-medium text-sm hover:from-blue-600 hover:to-purple-600 
                     transition-all duration-200 shadow-md hover:shadow-lg transform hover:scale-105"
            title="Zoom In"
          >
            +
          </button>
          <button
            onClick={onZoomOut}
            className="flex items-center justify-center w-8 h-8 rounded-lg bg-gradient-to-r from-slate-500 to-slate-600 
                     text-white font-medium text-sm hover:from-slate-600 hover:to-slate-700 
                     transition-all duration-200 shadow-md hover:shadow-lg transform hover:scale-105"
            title="Zoom Out"
          >
            −
          </button>
        </div>
        
        <button
          onClick={onCenterClick}
          className="w-full px-3 py-2 rounded-lg bg-gradient-to-r from-teal-500 to-cyan-500 
                   text-white font-medium text-xs hover:from-teal-600 hover:to-cyan-600 
                   transition-all duration-200 shadow-md hover:shadow-lg transform hover:scale-105 mb-2"
        >
          Center Graph
        </button>

        {/* Export Dropdown */}
        <div className="relative group">
          <button className="w-full px-3 py-2 rounded-lg bg-gradient-to-r from-pink-500 to-rose-500 
                           text-white font-medium text-xs hover:from-pink-600 hover:to-rose-600 
                           transition-all duration-200 shadow-md hover:shadow-lg transform hover:scale-105">
            Export ↓
          </button>
          <div className="absolute top-full mt-1 left-0 right-0 bg-white rounded-lg shadow-xl border 
                        border-white/20 opacity-0 group-hover:opacity-100 transition-opacity z-10">
            <button
              onClick={() => onExport('json')}
              className="w-full px-3 py-2 text-xs text-left hover:bg-slate-50 rounded-t-lg"
            >
              JSON
            </button>
            <button
              onClick={() => onExport('svg')}
              className="w-full px-3 py-2 text-xs text-left hover:bg-slate-50"
            >
              SVG
            </button>
            <button
              onClick={() => onExport('png')}
              className="w-full px-3 py-2 text-xs text-left hover:bg-slate-50 rounded-b-lg"
            >
              PNG
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

interface NodeTooltipProps {
  node: GraphNodeData;
  x: number;
  y: number;
  isVisible: boolean;
}

function NodeTooltip({ node, x, y, isVisible }: NodeTooltipProps) {
  if (!isVisible) return null;

  return (
    <div
      className="absolute pointer-events-none z-20 bg-white/95 backdrop-blur-md rounded-lg 
                 border border-white/20 shadow-xl p-3 max-w-xs"
      style={{
        left: x + 10,
        top: y - 50,
        transform: 'translate(0, -100%)'
      }}
    >
      <h4 className="font-semibold text-sm text-slate-800 mb-1">{node.title}</h4>
      <p className="text-xs text-slate-600 mb-2 line-clamp-3">{node.summary}</p>
      <div className="flex items-center justify-between text-xs">
        <span className="text-slate-500">Relevance: {Math.round((node.relevance_score || node.importance) * 100)}%</span>
        <a
          href={TesseraAPI.getWikipediaUrl(node.title)}
          target="_blank"
          rel="noopener noreferrer"
          className="text-blue-500 hover:text-blue-600 pointer-events-auto"
        >
          View →
        </a>
      </div>
    </div>
  );
}

export function KnowledgeGraph() {
  const [minRelevance, setMinRelevance] = useState(0.3);
  const [maxDepth, setMaxDepth] = useState(3);
  const [centerArticleId, setCenterArticleId] = useState<number | undefined>();
  const [selectedLayout, setSelectedLayout] = useState<string>('fruchterman_reingold');
  const [, setSelectedNode] = useState<GraphNodeData | null>(null);
  const [tooltip, setTooltip] = useState<{
    node: GraphNodeData;
    x: number;
    y: number;
    visible: boolean;
  } | null>(null);
  
  const svgRef = useRef<SVGSVGElement>(null);
  const simulationRef = useRef<d3.Simulation<GraphNodeData, undefined> | null>(null);
  const [transform, setTransform] = useState({ x: 0, y: 0, scale: 1 });

  // Query for knowledge graph data
  const { data: graphData, isLoading, error, refetch } = useQuery({
    queryKey: ['knowledge-graph', { minRelevance, maxDepth, centerArticleId }],
    queryFn: () => TesseraAPI.buildGraph({
      min_relevance: minRelevance,
      max_depth: maxDepth,
      center_article_id: centerArticleId,
      format: 'json'
    }),
    staleTime: 1000 * 60 * 5, // 5 minutes
  });

  // Query for R-powered advanced layouts
  const { data: layoutData, isLoading: layoutLoading } = useQuery({
    queryKey: ['graph-layouts', { minRelevance, maxDepth, centerArticleId }],
    queryFn: () => TesseraAPI.getGraphLayouts({
      min_relevance: minRelevance,
      max_depth: maxDepth,
      center_article_id: centerArticleId
    }),
    enabled: !!graphData?.data, // Only fetch layouts after we have graph data
    staleTime: 1000 * 60 * 5, // 5 minutes
  });

  // Process graph data for visualization with R-powered layouts
  const processedData = React.useMemo(() => {
    if (!graphData?.data) return null;

    const graph: KnowledgeGraphType = graphData.data;
    const layouts = (layoutData?.data as any)?.layouts; // eslint-disable-line @typescript-eslint/no-explicit-any
    const selectedLayoutData = layouts?.[selectedLayout];

    const nodes: GraphNodeData[] = Object.values(graph.nodes).map((node, index) => {
      // Use R-computed layout coordinates if available, otherwise fallback to random
      let x = Math.random() * 800;
      let y = Math.random() * 600;
      
      if (selectedLayoutData?.x && selectedLayoutData?.y) {
        // Scale and center the R layout coordinates
        const layoutX = selectedLayoutData.x[index];
        const layoutY = selectedLayoutData.y[index];
        if (layoutX !== undefined && layoutY !== undefined) {
          x = 400 + layoutX * 200; // Center at 400px with scaling
          y = 300 + layoutY * 200; // Center at 300px with scaling
        }
      }
      
      return {
        ...node,
        x,
        y,
      };
    });

    const edges = graph.edges.map(edge => ({
      source: edge.from,
      target: edge.to,
      weight: edge.weight,
      anchor_text: edge.anchor_text
    }));

    return { 
      nodes, 
      edges, 
      layouts: layouts || {}, 
      recommendations: (layoutData?.data as any)?.recommendations || {} // eslint-disable-line @typescript-eslint/no-explicit-any 
    };
  }, [graphData, layoutData, selectedLayout]);

  // Available layout algorithms from R
  const availableLayouts = React.useMemo(() => {
    const defaultLayouts = [
      'fruchterman_reingold',
      'kamada_kawai', 
      'spring_embedded',
      'large_graph',
      'stress_majorization',
      'mds',
      'clustered',
      'physics_simulation'
    ];
    
    // Use layouts from R response if available, otherwise use defaults
    if (processedData?.layouts && typeof processedData.layouts === 'object') {
      return Object.keys(processedData.layouts).filter(key => {
        const layout = (processedData.layouts as any)[key]; // eslint-disable-line @typescript-eslint/no-explicit-any
        return layout?.x && layout?.y;
      });
    }
    
    return defaultLayouts;
  }, [processedData?.layouts]);

  // Initialize D3 force simulation (now with R layout positions)
  useEffect(() => {
    if (!processedData || !svgRef.current) return;

    // Dynamic import of D3
    import('d3').then(d3 => {
      const { nodes, edges } = processedData;
      const svg = d3.select(svgRef.current);
      
      // Clear previous content
      svg.selectAll('*').remove();

      const width = 800;
      const height = 600;

      // Create simulation with reduced forces since we have R-computed positions
      const hasRLayout = processedData.layouts && processedData.layouts[selectedLayout];
      const simulation = d3.forceSimulation<GraphNodeData>(nodes)
        .force('link', d3.forceLink(edges)
          .id((d: any) => d.id) // eslint-disable-line @typescript-eslint/no-explicit-any
          .distance(d => hasRLayout ? 50 : 80 + (1 - d.weight) * 120)
          .strength(hasRLayout ? 0.1 : 1)) // Weaker link force if using R layout
        .force('charge', d3.forceManyBody().strength(hasRLayout ? -50 : -300)) // Weaker repulsion
        .force('center', d3.forceCenter(width / 2, height / 2))
        .force('collision', d3.forceCollide().radius(25))
        .alpha(hasRLayout ? 0.1 : 1) // Lower initial energy if using R layout
        .alphaDecay(hasRLayout ? 0.1 : 0.0228); // Faster settling if using R layout

      // Create gradient definitions
      const defs = svg.append('defs');
      
      // Node gradients based on node type
      const nodeColors: Record<string, [string, string]> = {
        person: ['#8b5cf6', '#a855f7'],    // Purple
        place: ['#06b6d4', '#0891b2'],     // Cyan  
        concept: ['#f59e0b', '#d97706'],   // Amber
        organization: ['#10b981', '#059669'], // Emerald
        event: ['#ef4444', '#dc2626'],     // Red
        technology: ['#3b82f6', '#2563eb'], // Blue
        general: ['#6b7280', '#4b5563']    // Gray
      };

      Object.entries(nodeColors).forEach(([type, [color1, color2]]) => {
        const gradient = defs.append('linearGradient')
          .attr('id', `gradient-${type}`)
          .attr('gradientUnits', 'objectBoundingBox');
        
        gradient.append('stop')
          .attr('offset', '0%')
          .attr('stop-color', color1);
        
        gradient.append('stop')
          .attr('offset', '100%')
          .attr('stop-color', color2);
      });

      // Create main group for zoomable content
      const g = svg.append('g');

      // Add zoom behavior
      const zoom = d3.zoom<SVGSVGElement, unknown>()
        .scaleExtent([0.1, 4])
        .on('zoom', (event) => {
          g.attr('transform', event.transform);
          setTransform({
            x: event.transform.x,
            y: event.transform.y,
            scale: event.transform.k
          });
        });

      svg.call(zoom as any); // eslint-disable-line @typescript-eslint/no-explicit-any

      // Create links
      const link = g.selectAll('.link')
        .data(edges)
        .enter()
        .append('line')
        .attr('class', 'link')
        .attr('stroke', 'rgba(148, 163, 184, 0.6)')
        .attr('stroke-width', d => Math.max(1, d.weight * 3))
        .attr('stroke-opacity', d => 0.3 + d.weight * 0.7);

      // Create nodes
      const node = g.selectAll('.node')
        .data(nodes)
        .enter()
        .append('g')
        .attr('class', 'node')
        .style('cursor', 'pointer');

      // Add circles for nodes
      node.append('circle')
        .attr('r', d => 8 + (d.relevance_score || d.importance) * 12)
        .attr('fill', d => `url(#gradient-${d.node_type || 'general'})`)
        .attr('stroke', '#fff')
        .attr('stroke-width', 2)
        .style('filter', 'drop-shadow(0 4px 8px rgba(0,0,0,0.2))');

      // Add labels
      node.append('text')
        .text(d => d.title.length > 20 ? d.title.substring(0, 20) + '...' : d.title)
        .attr('x', 0)
        .attr('y', d => 12 + (d.relevance_score || d.importance) * 12 + 14)
        .attr('text-anchor', 'middle')
        .attr('font-size', '11px')
        .attr('font-weight', '500')
        .attr('fill', '#1e293b')
        .style('pointer-events', 'none');

      // Add drag behavior
      const drag = d3.drag<SVGGElement, GraphNodeData>()
        .on('start', (event, d) => {
          if (!event.active) simulation.alphaTarget(0.3).restart();
          d.fx = d.x;
          d.fy = d.y;
        })
        .on('drag', (event, d) => {
          d.fx = event.x;
          d.fy = event.y;
        })
        .on('end', (event, d) => {
          if (!event.active) simulation.alphaTarget(0);
          d.fx = null;
          d.fy = null;
        });

      node.call(drag);

      // Add click and hover events
      node
        .on('click', (_event, d) => {
          setSelectedNode(d);
          setCenterArticleId(d.id);
        })
        .on('mouseenter', (event, d) => {
          const [mouseX, mouseY] = d3.pointer(event, svg.node());
          setTooltip({
            node: d,
            x: mouseX,
            y: mouseY,
            visible: true
          });
        })
        .on('mouseleave', () => {
          setTooltip(prev => prev ? { ...prev, visible: false } : null);
        });

      // Update positions on simulation tick
      simulation.on('tick', () => {
        link
          .attr('x1', (d: any) => (d.source as GraphNodeData).x) // eslint-disable-line @typescript-eslint/no-explicit-any
          .attr('y1', (d: any) => (d.source as GraphNodeData).y) // eslint-disable-line @typescript-eslint/no-explicit-any
          .attr('x2', (d: any) => (d.target as GraphNodeData).x) // eslint-disable-line @typescript-eslint/no-explicit-any
          .attr('y2', (d: any) => (d.target as GraphNodeData).y); // eslint-disable-line @typescript-eslint/no-explicit-any

        node.attr('transform', d => `translate(${d.x},${d.y})`);
      });

      simulationRef.current = simulation;
    });
  }, [processedData, selectedLayout]);

  const handleCenterGraph = useCallback(() => {
    if (!svgRef.current || !simulationRef.current) return;
    
    import('d3').then(d3 => {
      const svg = d3.select(svgRef.current);
      const zoom = d3.zoom<SVGSVGElement, unknown>();
      
      svg.transition()
        .duration(750)
        .call(zoom.transform as any, d3.zoomIdentity); // eslint-disable-line @typescript-eslint/no-explicit-any
    });
  }, []);

  const handleZoomIn = useCallback(() => {
    if (!svgRef.current) return;
    
    import('d3').then(d3 => {
      const svg = d3.select(svgRef.current);
      const zoom = d3.zoom<SVGSVGElement, unknown>();
      
      svg.transition()
        .duration(300)
        .call(zoom.scaleBy as any, 1.5); // eslint-disable-line @typescript-eslint/no-explicit-any
    });
  }, []);

  const handleZoomOut = useCallback(() => {
    if (!svgRef.current) return;
    
    import('d3').then(d3 => {
      const svg = d3.select(svgRef.current);
      const zoom = d3.zoom<SVGSVGElement, unknown>();
      
      svg.transition()
        .duration(300)
        .call(zoom.scaleBy as any, 0.67); // eslint-disable-line @typescript-eslint/no-explicit-any
    });
  }, []);

  const handleExport = useCallback((format: 'json' | 'svg' | 'png') => {
    if (format === 'json' && graphData?.data) {
      const blob = new Blob([JSON.stringify(graphData.data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'knowledge-graph.json';
      a.click();
      URL.revokeObjectURL(url);
    } else if (format === 'svg' && svgRef.current) {
      const svgData = new XMLSerializer().serializeToString(svgRef.current);
      const blob = new Blob([svgData], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'knowledge-graph.svg';
      a.click();
      URL.revokeObjectURL(url);
    }
  }, [graphData]);

  if (isLoading || layoutLoading) {
    return (
      <div className="flex-center min-h-[600px] bg-gradient-to-br from-slate-50 via-blue-50 to-purple-50 rounded-xl">
        <div className="text-center space-y-4">
          <div className="animate-spin w-12 h-12 border-4 border-purple-200 border-t-purple-500 rounded-full mx-auto"></div>
          <p className="text-slate-600 font-medium">
            {isLoading ? 'Building knowledge graph...' : 'Computing advanced layouts...'}
          </p>
          <p className="text-sm text-slate-500">
            {isLoading ? 'Analyzing connections and relevance scores' : 'Running R algorithms for optimal positioning'}
          </p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex-center min-h-[600px] bg-gradient-to-br from-red-50 to-orange-50 rounded-xl">
        <div className="text-center space-y-4">
          <div className="w-16 h-16 bg-gradient-to-br from-red-500 to-orange-500 rounded-full flex-center mx-auto">
            <span className="text-white text-2xl">⚠</span>
          </div>
          <p className="text-slate-800 font-semibold">Failed to load knowledge graph</p>
          <p className="text-sm text-slate-600 max-w-md">{error.message}</p>
          <button
            onClick={() => refetch()}
            className="px-6 py-2 bg-gradient-to-r from-red-500 to-orange-500 text-white 
                     rounded-lg font-medium hover:from-red-600 hover:to-orange-600 
                     transition-all duration-200 transform hover:scale-105"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (!processedData || processedData.nodes.length === 0) {
    return (
      <div className="flex-center min-h-[600px] bg-gradient-to-br from-slate-50 via-indigo-50 to-purple-50 rounded-xl">
        <div className="text-center space-y-4">
          <div className="w-16 h-16 bg-gradient-to-br from-indigo-500 to-purple-500 rounded-full flex-center mx-auto">
            <span className="text-white text-2xl">📊</span>
          </div>
          <p className="text-slate-800 font-semibold">No knowledge graph data available</p>
          <p className="text-sm text-slate-600 max-w-md">
            Try crawling some Wikipedia articles first, or adjust the relevance threshold.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="relative w-full h-[700px] bg-gradient-to-br from-slate-50 via-blue-50 to-purple-50 rounded-xl overflow-hidden">
      {/* Graph Visualization */}
      <svg
        ref={svgRef}
        width="100%"
        height="100%"
        className="cursor-move"
      />

      {/* Controls */}
      <GraphControls
        onCenterClick={handleCenterGraph}
        onZoomIn={handleZoomIn}
        onZoomOut={handleZoomOut}
        onExport={handleExport}
        minRelevance={minRelevance}
        onMinRelevanceChange={setMinRelevance}
        maxDepth={maxDepth}
        onMaxDepthChange={setMaxDepth}
        selectedLayout={selectedLayout}
        onLayoutChange={setSelectedLayout}
        availableLayouts={availableLayouts}
        layoutRecommendations={processedData?.recommendations as Record<string, string[]> | undefined}
      />

      {/* Node Tooltip */}
      {tooltip && (
        <NodeTooltip
          node={tooltip.node}
          x={tooltip.x}
          y={tooltip.y}
          isVisible={tooltip.visible}
        />
      )}

      {/* Graph Statistics */}
      <div className="absolute bottom-4 left-4 bg-white/90 backdrop-blur-md rounded-lg 
                    border border-white/20 shadow-lg p-3">
        <div className="text-xs text-slate-600 space-y-1">
          <div>Nodes: {processedData.nodes.length}</div>
          <div>Edges: {processedData.edges.length}</div>
          <div>Scale: {Math.round(transform.scale * 100)}%</div>
        </div>
      </div>

      {/* Legend */}
      <div className="absolute bottom-4 right-4 bg-white/90 backdrop-blur-md rounded-lg 
                    border border-white/20 shadow-lg p-3">
        <h4 className="text-xs font-semibold text-slate-800 mb-2">Node Types</h4>
        <div className="space-y-1 text-xs">
          {Object.entries({
            person: '👤 Person',
            place: '📍 Place', 
            concept: '💡 Concept',
            organization: '🏢 Organization',
            event: '📅 Event',
            technology: '⚡ Technology',
            general: '📄 General'
          }).map(([type, label]) => (
            <div key={type} className="flex items-center space-x-2">
              <div 
                className={`w-3 h-3 rounded-full ${
                  type === 'person' ? 'bg-purple-500' :
                  type === 'place' ? 'bg-green-500' :
                  type === 'concept' ? 'bg-yellow-500' :
                  type === 'organization' ? 'bg-blue-500' :
                  type === 'event' ? 'bg-red-500' :
                  type === 'technology' ? 'bg-orange-500' :
                  'bg-gray-500'
                }`}
              />
              <span className="text-slate-600">{label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

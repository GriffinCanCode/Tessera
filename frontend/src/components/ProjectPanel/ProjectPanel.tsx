import React, { useState, useEffect } from 'react';
import { 
  Plus, 
  Search, 
  BookOpen,
  ChevronDown,
  ChevronRight,
  Trash2,
  Users
} from 'lucide-react';
import TesseraAPI from '../../services/api';
import type { Project } from '../../types/api';

interface ProjectPanelProps {
  currentProjectId: number | null;
  onProjectChange: (projectId: number | null) => void;
  className?: string;
}

interface NewProjectModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreateProject: (projectData: Partial<Project>) => void;
}

const NewProjectModal: React.FC<NewProjectModalProps> = ({ 
  isOpen, 
  onClose, 
  onCreateProject 
}) => {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [color, setColor] = useState('#3b82f6');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const predefinedColors = [
    '#3b82f6', // Blue
    '#10b981', // Green
    '#f59e0b', // Amber
    '#ef4444', // Red
    '#8b5cf6', // Purple
    '#06b6d4', // Cyan
    '#f97316', // Orange
    '#84cc16', // Lime
  ];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setIsSubmitting(true);
    try {
      await onCreateProject({
        name: name.trim(),
        description: description.trim(),
        color
      });
      
      // Reset form
      setName('');
      setDescription('');
      setColor('#3b82f6');
      onClose();
    } catch (error) {
      console.error('Failed to create project:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-96 max-w-90vw">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Create New Project</h3>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Project Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Enter project name..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              required
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Description (Optional)
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Describe your project..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
              rows={3}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Color
            </label>
            <div className="flex space-x-2">
              {predefinedColors.map((colorOption) => (
                <button
                  key={colorOption}
                  type="button"
                  onClick={() => setColor(colorOption)}
                  className={`w-8 h-8 rounded-full border-2 ${
                    color === colorOption ? 'border-gray-400' : 'border-gray-200'
                  }`}
                  style={{ backgroundColor: colorOption }}
                />
              ))}
            </div>
          </div>
          
          <div className="flex justify-end space-x-3 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-600 border border-gray-300 rounded-md hover:bg-gray-50"
              disabled={isSubmitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!name.trim() || isSubmitting}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Creating...' : 'Create Project'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

const ProjectPanel: React.FC<ProjectPanelProps> = ({ 
  currentProjectId, 
  onProjectChange, 
  className = '' 
}) => {
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [showNewProjectModal, setShowNewProjectModal] = useState(false);
  const [expandedProject, setExpandedProject] = useState<number | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    loadProjects();
  }, []);

  const loadProjects = async () => {
    try {
      setLoading(true);
      const response = await TesseraAPI.listProjects();
      if (response.success && response.data) {
        setProjects(response.data.projects);
        
        // If no current project is selected, select the default project
        if (!currentProjectId && response.data.projects.length > 0) {
          const defaultProject = response.data.projects.find(p => p.is_default) || response.data.projects[0];
          onProjectChange(defaultProject.id);
        }
      }
    } catch (error) {
      console.error('Failed to load projects:', error);
    } finally {
      setLoading(false);
    }
  };

  const createProject = async (projectData: Partial<Project>) => {
    try {
      const response = await TesseraAPI.createProject(projectData);
      if (response.success && response.data) {
        await loadProjects();
        onProjectChange(response.data.project.id);
      }
    } catch (error) {
      console.error('Failed to create project:', error);
    }
  };

  const deleteProject = async (projectId: number) => {
    if (!confirm('Are you sure you want to delete this project? Articles will be moved to the default project.')) {
      return;
    }

    try {
      const response = await TesseraAPI.deleteProject(projectId);
      if (response.success) {
        await loadProjects();
        
        // If we deleted the current project, switch to default
        if (projectId === currentProjectId) {
          const defaultProject = projects.find(p => p.is_default);
          onProjectChange(defaultProject?.id || null);
        }
      }
    } catch (error) {
      console.error('Failed to delete project:', error);
    }
  };

  const currentProject = projects.find(p => p.id === currentProjectId);
  
  const filteredProjects = projects.filter(project =>
    project.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    project.description?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className={`flex items-center justify-center p-4 ${className}`}>
        <div className="text-gray-500">Loading projects...</div>
      </div>
    );
  }

  return (
    <div className={`${className}`}>
      {/* Current Project Header */}
      <div className="p-4 border-b border-gray-200">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center space-x-2">
            <div 
              className="w-3 h-3 rounded-full"
              style={{ backgroundColor: currentProject?.color || '#3b82f6' }}
            />
            <span className="font-medium text-gray-900 truncate">
              {currentProject?.name || 'No Project Selected'}
            </span>
          </div>
          <button
            onClick={() => setShowNewProjectModal(true)}
            className="p-1 text-gray-400 hover:text-blue-600"
            title="Create new project"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>
        
        {currentProject?.description && (
          <p className="text-xs text-gray-600 mb-3">{currentProject.description}</p>
        )}
        
        {/* Project Stats */}
        {currentProject && (
          <div className="grid grid-cols-3 gap-2 text-xs">
            <div className="text-center p-2 bg-gray-50 rounded">
              <div className="font-medium text-gray-900">{currentProject.article_count || 0}</div>
              <div className="text-gray-500">Articles</div>
            </div>
            <div className="text-center p-2 bg-gray-50 rounded">
              <div className="font-medium text-gray-900">{currentProject.link_count || 0}</div>
              <div className="text-gray-500">Links</div>
            </div>
            <div className="text-center p-2 bg-gray-50 rounded">
              <div className="font-medium text-gray-900">{currentProject.chunk_count || 0}</div>
              <div className="text-gray-500">Chunks</div>
            </div>
          </div>
        )}
      </div>

      {/* Search */}
      <div className="p-4 border-b border-gray-200">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search projects..."
            className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* Projects List */}
      <div className="flex-1 overflow-y-auto">
        {filteredProjects.length === 0 ? (
          <div className="p-4 text-center text-gray-500 text-sm">
            {searchQuery ? 'No projects match your search' : 'No projects yet'}
          </div>
        ) : (
          filteredProjects.map((project) => (
            <div key={project.id} className="border-b border-gray-100 last:border-b-0">
              <div
                className={`flex items-center p-3 cursor-pointer hover:bg-gray-50 ${
                  project.id === currentProjectId ? 'bg-blue-50' : ''
                }`}
                onClick={() => onProjectChange(project.id)}
              >
                <div className="flex items-center flex-1 min-w-0">
                  <div 
                    className="w-3 h-3 rounded-full mr-3 flex-shrink-0"
                    style={{ backgroundColor: project.color }}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-medium text-gray-900 truncate flex items-center">
                      {project.name}
                      {project.is_default && (
                        <span className="ml-2 px-1.5 py-0.5 text-xs bg-gray-200 text-gray-600 rounded">
                          Default
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-gray-500">
                      {project.article_count || 0} articles
                    </div>
                  </div>
                </div>
                
                <div className="flex items-center space-x-1">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setExpandedProject(expandedProject === project.id ? null : project.id);
                    }}
                    className="p-1 text-gray-400 hover:text-gray-600"
                  >
                    {expandedProject === project.id ? (
                      <ChevronDown className="w-4 h-4" />
                    ) : (
                      <ChevronRight className="w-4 h-4" />
                    )}
                  </button>
                  
                  {!project.is_default && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteProject(project.id);
                      }}
                      className="p-1 text-gray-400 hover:text-red-600"
                      title="Delete project"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  )}
                </div>
              </div>
              
              {/* Expanded Project Details */}
              {expandedProject === project.id && (
                <div className="px-6 pb-3 bg-gray-50">
                  {project.description && (
                    <p className="text-xs text-gray-600 mb-2">{project.description}</p>
                  )}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="flex items-center space-x-1 text-gray-500">
                      <BookOpen className="w-3 h-3" />
                      <span>{project.link_count || 0} links</span>
                    </div>
                    <div className="flex items-center space-x-1 text-gray-500">
                      <Users className="w-3 h-3" />
                      <span>{project.chunk_count || 0} chunks</span>
                    </div>
                  </div>
                  {project.last_activity && (
                    <div className="text-xs text-gray-500 mt-2">
                      Last activity: {new Date(project.last_activity * 1000).toLocaleDateString()}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {/* New Project Modal */}
      <NewProjectModal
        isOpen={showNewProjectModal}
        onClose={() => setShowNewProjectModal(false)}
        onCreateProject={createProject}
      />
    </div>
  );
};

export default ProjectPanel;

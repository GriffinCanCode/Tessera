import React, { useState, useEffect, useRef } from 'react';
import { Lightbulb } from 'lucide-react';
import WikiCrawlerAPI from '../../services/api';
import { ProjectPanel } from '../ProjectPanel';
import type { 
  BotMessage, 
  ConversationInfo, 
  ChatResponse, 
  KnowledgeQueryResponse 
} from '../../types/api';

interface NotebookProps {
  className?: string;
}

const Notebook: React.FC<NotebookProps> = ({ className = '' }) => {
  // State management
  const [currentConversation, setCurrentConversation] = useState<string>('');
  const [messages, setMessages] = useState<BotMessage[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [conversations, setConversations] = useState<ConversationInfo[]>([]);
  const [selectedMode, setSelectedMode] = useState<'chat' | 'knowledge'>('chat');
  const [temperature, setTemperature] = useState(0.7);
  const [includeInsights, setIncludeInsights] = useState(true);
  const [showSettings, setShowSettings] = useState(false);
  const [currentProjectId, setCurrentProjectId] = useState<number | null>(null);
  
  // Refs
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Auto-scroll to bottom when new messages arrive
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Load conversations on mount
  useEffect(() => {
    loadConversations();
    createNewConversation();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const loadConversations = async () => {
    try {
      const response = await WikiCrawlerAPI.listConversations();
      if (response.success && response.data) {
        setConversations(response.data.conversations);
      }
    } catch (error) {
      console.error('Failed to load conversations:', error);
    }
  };

  const createNewConversation = async () => {
    try {
      const response = await WikiCrawlerAPI.createConversation();
      if (response.success && response.data) {
        setCurrentConversation(response.data.conversation_id);
        setMessages([]);
        await loadConversations(); // Refresh conversation list
      }
    } catch (error) {
      console.error('Failed to create conversation:', error);
    }
  };

  const loadConversationHistory = async (conversationId: string) => {
    try {
      const response = await WikiCrawlerAPI.getConversationHistory(conversationId);
      if (response.success && response.data) {
        setCurrentConversation(conversationId);
        setMessages(response.data.messages);
      }
    } catch (error) {
      console.error('Failed to load conversation history:', error);
    }
  };

  const sendMessage = async () => {
    if (!inputMessage.trim() || !currentConversation || isLoading) return;

    const userMessage: BotMessage = {
      role: 'user',
      content: inputMessage.trim(),
      timestamp: new Date().toISOString(),
    };

    // Add user message to UI immediately
    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');
    setIsLoading(true);

    try {
      let response: ChatResponse | KnowledgeQueryResponse;
      
      if (selectedMode === 'knowledge') {
        // Use knowledge query endpoint
        const knowledgeResponse = await WikiCrawlerAPI.knowledgeQuery({
          query: userMessage.content,
          conversation_id: currentConversation,
          include_recent: true,
        });
        
        if (knowledgeResponse.success && knowledgeResponse.data) {
          response = {
            conversation_id: currentConversation,
            message: knowledgeResponse.data.answer,
            timestamp: new Date().toISOString(),
            context_used: knowledgeResponse.data.sources.length > 0,
          } as ChatResponse;

          // Add sources information if available
          if (knowledgeResponse.data.sources.length > 0) {
            response.message += `\n\n**Sources:** ${knowledgeResponse.data.sources.join(', ')}`;
          }
          
          if (knowledgeResponse.data.confidence < 0.8) {
            response.message += `\n\n*Confidence: ${Math.round(knowledgeResponse.data.confidence * 100)}%*`;
          }
        } else {
          throw new Error(knowledgeResponse.error || 'Knowledge query failed');
        }
      } else {
        // Use regular chat endpoint with project context
        const chatRequest = {
          conversation_id: currentConversation,
          message: userMessage.content,
          temperature,
          include_insights: includeInsights,
          project_id: currentProjectId || undefined,
        };
        
        const chatResponse = await WikiCrawlerAPI.chatWithBotProject(chatRequest);
        
        if (chatResponse.success && chatResponse.data) {
          response = chatResponse.data;
        } else {
          throw new Error(chatResponse.error || 'Chat failed');
        }
      }

      // Add bot response
      const botMessage: BotMessage = {
        role: 'assistant',
        content: response.message,
        timestamp: response.timestamp,
      };

      setMessages(prev => [...prev, botMessage]);
      
      // Refresh conversations list to update message count
      await loadConversations();
      
    } catch (error) {
      console.error('Failed to send message:', error);
      
      // Add error message
      const errorMessage: BotMessage = {
        role: 'assistant',
        content: `Sorry, I encountered an error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        timestamp: new Date().toISOString(),
      };
      
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  const deleteConversation = async (conversationId: string) => {
    try {
      await WikiCrawlerAPI.deleteConversation(conversationId);
      
      // If we deleted the current conversation, create a new one
      if (conversationId === currentConversation) {
        await createNewConversation();
      }
      
      await loadConversations();
    } catch (error) {
      console.error('Failed to delete conversation:', error);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const formatTimestamp = (timestamp?: string) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatConversationTime = (timestamp: string) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const hours = diff / (1000 * 60 * 60);
    
    if (hours < 1) return 'Just now';
    if (hours < 24) return `${Math.floor(hours)}h ago`;
    return date.toLocaleDateString();
  };

  return (
    <div className={`flex h-screen bg-gray-50 ${className}`}>
      {/* Sidebar - Conversations */}
      <div className="w-80 bg-white border-r border-gray-200 flex flex-col">
        <div className="p-4 border-b border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Knowledge Bot</h2>
            <button
              onClick={createNewConversation}
              className="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              New Chat
            </button>
          </div>
          
          {/* Mode Selection */}
          <div className="flex rounded-lg bg-gray-100 p-1 mb-4">
            <button
              onClick={() => setSelectedMode('chat')}
              className={`flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors ${
                selectedMode === 'chat'
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              Chat
            </button>
            <button
              onClick={() => setSelectedMode('knowledge')}
              className={`flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors ${
                selectedMode === 'knowledge'
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              Knowledge
            </button>
          </div>
          
          {/* Project Selection */}
          <ProjectPanel
            currentProjectId={currentProjectId}
            onProjectChange={setCurrentProjectId}
          />
        </div>

        {/* Conversations List */}
        <div className="flex-1 overflow-y-auto">
          {conversations.length === 0 ? (
            <div className="p-4 text-gray-500 text-sm">
              No conversations yet. Start a new chat!
            </div>
          ) : (
            conversations.map((conv) => (
              <div
                key={conv.conversation_id}
                className={`p-4 border-b border-gray-100 cursor-pointer hover:bg-gray-50 ${
                  conv.conversation_id === currentConversation ? 'bg-blue-50' : ''
                }`}
                onClick={() => loadConversationHistory(conv.conversation_id)}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-gray-900 truncate">
                      Conversation {conv.conversation_id.split('_')[1]}
                    </div>
                    <div className="text-xs text-gray-500 mt-1">
                      {conv.message_count} messages • {formatConversationTime(conv.last_activity)}
                    </div>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      deleteConversation(conv.conversation_id);
                    }}
                    className="ml-2 text-gray-400 hover:text-red-600"
                  >
                    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Settings Toggle */}
        <div className="p-4 border-t border-gray-200">
          <button
            onClick={() => setShowSettings(!showSettings)}
            className="w-full text-left text-sm text-gray-600 hover:text-gray-800 flex items-center"
          >
            <svg className={`h-4 w-4 mr-2 transition-transform ${showSettings ? 'rotate-90' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
            Settings
          </button>
          
          {showSettings && (
            <div className="mt-3 space-y-3">
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">
                  Creativity: {temperature}
                </label>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.1"
                  value={temperature}
                  onChange={(e) => setTemperature(parseFloat(e.target.value))}
                  className="w-full"
                />
              </div>
              
              <div>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={includeInsights}
                    onChange={(e) => setIncludeInsights(e.target.checked)}
                    className="mr-2"
                  />
                  <span className="text-xs text-gray-700">Include knowledge insights</span>
                </label>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col">
        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          {messages.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-gray-400 mb-4">
                <svg className="h-16 w-16 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
              </div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                {selectedMode === 'chat' ? 'Start a conversation' : 'Ask about your knowledge'}
              </h3>
              <p className="text-gray-500 max-w-md mx-auto">
                {selectedMode === 'chat' 
                  ? 'Chat with your AI assistant about the Wikipedia articles you\'ve crawled. I can help you explore connections and discover insights.'
                  : 'Ask specific questions about your knowledge base. I\'ll search through your crawled articles and provide detailed answers with sources.'
                }
              </p>
            </div>
          ) : (
            messages.map((message, index) => (
              <div
                key={index}
                className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-3xl px-4 py-3 rounded-lg ${
                    message.role === 'user'
                      ? 'bg-blue-600 text-white'
                      : 'bg-white border border-gray-200 text-gray-900'
                  }`}
                >
                  <div className="whitespace-pre-wrap">{message.content}</div>
                  {message.timestamp && (
                    <div
                      className={`text-xs mt-1 ${
                        message.role === 'user' ? 'text-blue-100' : 'text-gray-500'
                      }`}
                    >
                      {formatTimestamp(message.timestamp)}
                    </div>
                  )}
                </div>
              </div>
            ))
          )}
          
          {isLoading && (
            <div className="flex justify-start">
              <div className="bg-white border border-gray-200 rounded-lg px-4 py-3">
                <div className="flex items-center space-x-2">
                  <div className="flex space-x-1">
                    <div className="h-2 w-2 bg-gray-400 rounded-full animate-pulse"></div>
                    <div className="h-2 w-2 bg-gray-400 rounded-full animate-pulse delay-75"></div>
                    <div className="h-2 w-2 bg-gray-400 rounded-full animate-pulse delay-150"></div>
                  </div>
                  <span className="text-sm text-gray-500">Thinking...</span>
                </div>
              </div>
            </div>
          )}
          
          <div ref={messagesEndRef} />
        </div>

        {/* Input Area */}
        <div className="border-t border-gray-200 bg-white p-4">
          <div className="flex items-end space-x-3">
            <div className="flex-1">
              <textarea
                ref={inputRef}
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder={
                  selectedMode === 'chat' 
                    ? "Chat about your knowledge..." 
                    : "Ask a question about your knowledge base..."
                }
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                rows={Math.min(Math.max(inputMessage.split('\n').length, 1), 4)}
                disabled={isLoading || !currentConversation}
              />
            </div>
            <button
              onClick={sendMessage}
              disabled={!inputMessage.trim() || isLoading || !currentConversation}
              className="px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
            </button>
          </div>
          
          {selectedMode === 'knowledge' && (
            <div className="mt-2 text-xs text-gray-500 flex items-center space-x-1">
              <Lightbulb className="w-3 h-3 text-amber-500" />
              <span>Knowledge mode searches your crawled articles and provides detailed answers with sources</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Notebook;

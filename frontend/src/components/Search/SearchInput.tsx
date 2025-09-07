import { Search, X, Loader2, Sparkles } from 'lucide-react';

interface SearchInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  isLoading?: boolean;
}

export function SearchInput({ value, onChange, placeholder, isLoading }: SearchInputProps) {
  console.log('SearchInput render:', { value, placeholder, isLoading });
  
  const handleChange = (newValue: string) => {
    console.log('SearchInput onChange called:', { oldValue: value, newValue });
    onChange(newValue);
  };

  return (
    <div className="relative group">
      {/* Enhanced Icon Section */}
      <div className="absolute inset-y-0 left-0 pl-6 flex items-center pointer-events-none">
        {isLoading ? (
          <div className="relative">
            <Loader2 className="h-6 w-6 text-purple-500 animate-spin" />
            <div className="absolute inset-0 h-6 w-6 border-2 border-teal-400/30 rounded-full animate-ping"></div>
          </div>
        ) : (
          <div className="relative">
            <Search className="h-6 w-6 text-slate-400 group-focus-within:text-purple-500 transition-all duration-300" />
            {!value && (
              <Sparkles className="absolute -top-1 -right-1 h-3 w-3 text-purple-400 opacity-0 group-hover:opacity-100 transition-all duration-300 animate-pulse" />
            )}
          </div>
        )}
      </div>

      {/* Enhanced Input Field */}
      <input
        type="text"
        value={value}
        onChange={e => handleChange(e.target.value)}
        placeholder={placeholder}
        className="block w-full pl-16 pr-16 py-6 text-lg border-2 border-slate-200/50 
                 rounded-2xl bg-white/95 backdrop-blur-sm text-slate-800 placeholder-slate-400 
                 focus:outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-500/20 
                 hover:border-slate-300 hover:bg-white transition-all duration-300 shadow-lg
                 group-hover:shadow-xl font-medium relative z-10"
      />

      {/* Enhanced Clear Button */}
      {value && (
        <button
          onClick={() => handleChange('')}
          className="absolute inset-y-0 right-0 pr-6 flex items-center group/clear"
        >
          <div className="relative p-1 rounded-full hover:bg-slate-100 transition-all duration-200">
            <X className="h-5 w-5 text-slate-400 group-hover/clear:text-slate-600 transition-colors" />
            <div className="absolute inset-0 bg-gradient-to-r from-red-400/20 to-pink-400/20 rounded-full opacity-0 group-hover/clear:opacity-100 transition-opacity duration-300"></div>
          </div>
        </button>
      )}

      {/* Subtle Border Glow Effect */}
      <div className="absolute -inset-1 bg-gradient-to-r from-purple-500/10 via-blue-500/5 to-teal-500/10 rounded-3xl blur opacity-0 group-focus-within:opacity-100 transition-all duration-500 pointer-events-none"></div>
    </div>
  );
}

using AutoMapper;
using MODEL.DTOs;
using MODEL.Entities;

namespace API
{
    public class AutoMapperProfile : Profile
    {
        public AutoMapperProfile()
        {
            CreateMap<Log, AddLogDTO>();
            CreateMap<AddLogDTO, Log>();

            CreateMap<Todo, AddTodoDTO>();
            CreateMap<AddTodoDTO, Todo>();

            CreateMap<TextToSpeechHistory, TextToSpeechDTO>();
            CreateMap<TextToSpeechDTO, TextToSpeechHistory>();

            CreateMap<Lexicon, AddLexiconDTO>();
            CreateMap<AddLexiconDTO, Lexicon>();
        }
    }
}

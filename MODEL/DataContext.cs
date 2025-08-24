using Microsoft.EntityFrameworkCore;
using MODEL.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace MODEL
{
    public class DataContext: DbContext
    {
        public DataContext(DbContextOptions<DataContext> options) : base(options)
        {

        }
        public virtual DbSet<Quotation> Quotation { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Quotation>(entity =>
            {
                entity.ToTable("Quotation", "dbo");
            });
            //base.OnModelCreating(modelBuilder);
        }
        public DbSet<Log> Log { get; set; }
        public DbSet<Users> Users { get; set; }
        public DbSet<Role> Role { get; set; }
        public DbSet<Todo> Todo { get; set; }
        public DbSet<TextToSpeechHistory> TextToSpeechHistory { get; set; }
        public DbSet<Lexicon> Lexicon { get; set; }
    }
}

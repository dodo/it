
typedef size_t SDL_PixelFormat;
typedef size_t SDL_BlitMap;

// from SDL2/SDL_rect.h

typedef struct _SDL_Rect {
    int x, y;
    int w, h;
} SDL_Rect;

// from SDL2/SDL_surface.h

typedef struct _SDL_Surface {
    uint32_t flags;               /**< Read-only */
    SDL_PixelFormat *format;    /**< Read-only */
    int w, h;                   /**< Read-only */
    int pitch;                  /**< Read-only */
    void *pixels;               /**< Read-write */

    /** Application data associated with the surface */
    void *userdata;             /**< Read-write */

    /** information needed for surfaces requiring locks */
    int locked;                 /**< Read-only */
    void *lock_data;            /**< Read-only */

    /** clipping information */
    SDL_Rect clip_rect;         /**< Read-only */

    /** info for fast blit mapping to other surfaces */
    /*struct*/ SDL_BlitMap *map;    /**< Private */

    /** Reference count -- used when freeing surface */
    int refcount;               /**< Read-mostly */
} SDL_Surface;

void SDL_FreeSurface(SDL_Surface* surface);

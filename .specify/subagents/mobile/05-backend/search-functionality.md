---
name: Mobile Backend Search Functionality
platform: mobile
description: Search functionality implementation for mobile backends including Elasticsearch integration, Algolia setup, full-text search, autocomplete, faceted search, and search analytics
model: opus
category: mobile/backend
---

# Mobile Backend Search Functionality Subagent

## Purpose

This subagent handles all aspects of search functionality for mobile backends. Mobile applications require fast, relevant search with features like autocomplete, typo tolerance, and faceted filtering. The implementation supports both Elasticsearch for self-hosted solutions and Algolia for managed search.

## Core Responsibilities

1. Search infrastructure setup (Elasticsearch/Algolia)
2. Index management and mapping
3. Data synchronization with primary database
4. Full-text search with relevance tuning
5. Autocomplete and suggestions
6. Faceted search and filtering
7. Search analytics and optimization
8. Mobile-optimized search responses

## Elasticsearch Implementation

### Elasticsearch Client Setup

```typescript
// src/services/elasticsearchService.ts
import { Client } from '@elastic/elasticsearch';
import { config } from '../config';
import { logger } from '../utils/logger';

const esClient = new Client({
  node: config.ELASTICSEARCH_URL,
  auth: config.ELASTICSEARCH_API_KEY ? {
    apiKey: config.ELASTICSEARCH_API_KEY,
  } : undefined,
  maxRetries: 3,
  requestTimeout: 30000,
  sniffOnStart: config.NODE_ENV === 'production',
});

// Verify connection
export async function checkElasticsearchConnection(): Promise<boolean> {
  try {
    const health = await esClient.cluster.health();
    logger.info('Elasticsearch cluster health', { status: health.status });
    return health.status !== 'red';
  } catch (error) {
    logger.error('Elasticsearch connection failed', { error: error.message });
    return false;
  }
}

export { esClient };
```

### Index Management

```typescript
// src/search/indices/posts.ts
import { esClient } from '../elasticsearchService';

const POSTS_INDEX = 'posts';

// Index mapping for posts
const postsMapping = {
  settings: {
    number_of_shards: 2,
    number_of_replicas: 1,
    analysis: {
      analyzer: {
        // Custom analyzer for better text search
        content_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: [
            'lowercase',
            'asciifolding',
            'word_delimiter_graph',
            'english_stemmer',
            'english_stop',
          ],
        },
        // Autocomplete analyzer
        autocomplete_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: [
            'lowercase',
            'asciifolding',
            'autocomplete_filter',
          ],
        },
        // Search analyzer for autocomplete
        autocomplete_search: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'asciifolding'],
        },
      },
      filter: {
        english_stemmer: {
          type: 'stemmer',
          language: 'english',
        },
        english_stop: {
          type: 'stop',
          stopwords: '_english_',
        },
        autocomplete_filter: {
          type: 'edge_ngram',
          min_gram: 2,
          max_gram: 20,
        },
      },
    },
  },
  mappings: {
    dynamic: 'strict',
    properties: {
      id: { type: 'keyword' },
      userId: { type: 'keyword' },
      title: {
        type: 'text',
        analyzer: 'content_analyzer',
        fields: {
          autocomplete: {
            type: 'text',
            analyzer: 'autocomplete_analyzer',
            search_analyzer: 'autocomplete_search',
          },
          keyword: {
            type: 'keyword',
          },
        },
      },
      body: {
        type: 'text',
        analyzer: 'content_analyzer',
      },
      tags: { type: 'keyword' },
      category: { type: 'keyword' },
      visibility: { type: 'keyword' },
      likesCount: { type: 'integer' },
      commentsCount: { type: 'integer' },
      author: {
        type: 'object',
        properties: {
          id: { type: 'keyword' },
          displayName: {
            type: 'text',
            fields: {
              autocomplete: {
                type: 'text',
                analyzer: 'autocomplete_analyzer',
                search_analyzer: 'autocomplete_search',
              },
              keyword: { type: 'keyword' },
            },
          },
          avatarUrl: { type: 'keyword', index: false },
        },
      },
      location: { type: 'geo_point' },
      createdAt: { type: 'date' },
      updatedAt: { type: 'date' },
    },
  },
};

export async function createPostsIndex(): Promise<void> {
  const exists = await esClient.indices.exists({ index: POSTS_INDEX });

  if (!exists) {
    await esClient.indices.create({
      index: POSTS_INDEX,
      ...postsMapping,
    });
    logger.info('Posts index created');
  }
}

export async function deletePostsIndex(): Promise<void> {
  const exists = await esClient.indices.exists({ index: POSTS_INDEX });

  if (exists) {
    await esClient.indices.delete({ index: POSTS_INDEX });
    logger.info('Posts index deleted');
  }
}

export async function reindexPosts(): Promise<void> {
  // Create new index with timestamp
  const newIndex = `${POSTS_INDEX}_${Date.now()}`;

  await esClient.indices.create({
    index: newIndex,
    ...postsMapping,
  });

  // Reindex from old to new
  await esClient.reindex({
    source: { index: POSTS_INDEX },
    dest: { index: newIndex },
  });

  // Update alias
  await esClient.indices.updateAliases({
    actions: [
      { remove: { index: `${POSTS_INDEX}_*`, alias: POSTS_INDEX } },
      { add: { index: newIndex, alias: POSTS_INDEX } },
    ],
  });

  logger.info('Posts reindexed successfully');
}
```

### Search Service

```typescript
// src/services/searchService.ts
import { esClient } from './elasticsearchService';
import { db } from '../database';
import { logger } from '../utils/logger';

interface SearchOptions {
  query: string;
  userId?: string;
  filters?: {
    category?: string;
    tags?: string[];
    dateFrom?: Date;
    dateTo?: Date;
    visibility?: string;
    location?: {
      lat: number;
      lng: number;
      radiusKm: number;
    };
  };
  sort?: 'relevance' | 'newest' | 'oldest' | 'popular' | 'nearest';
  page?: number;
  limit?: number;
  includeAggregations?: boolean;
}

interface SearchResult<T> {
  items: T[];
  total: number;
  aggregations?: Record<string, any>;
  suggestions?: string[];
  took: number;
}

export class SearchService {
  // Full-text search
  async searchPosts(options: SearchOptions): Promise<SearchResult<any>> {
    const {
      query,
      userId,
      filters = {},
      sort = 'relevance',
      page = 1,
      limit = 20,
      includeAggregations = false,
    } = options;

    const must: any[] = [];
    const filter: any[] = [];

    // Main search query
    if (query) {
      must.push({
        multi_match: {
          query,
          fields: [
            'title^3',
            'title.autocomplete^2',
            'body',
            'tags^2',
            'author.displayName',
          ],
          type: 'best_fields',
          fuzziness: 'AUTO',
          prefix_length: 2,
        },
      });
    } else {
      must.push({ match_all: {} });
    }

    // Visibility filter
    filter.push({
      bool: {
        should: [
          { term: { visibility: 'public' } },
          ...(userId ? [{ term: { userId } }] : []),
        ],
      },
    });

    // Category filter
    if (filters.category) {
      filter.push({ term: { category: filters.category } });
    }

    // Tags filter
    if (filters.tags && filters.tags.length > 0) {
      filter.push({ terms: { tags: filters.tags } });
    }

    // Date range filter
    if (filters.dateFrom || filters.dateTo) {
      filter.push({
        range: {
          createdAt: {
            ...(filters.dateFrom && { gte: filters.dateFrom.toISOString() }),
            ...(filters.dateTo && { lte: filters.dateTo.toISOString() }),
          },
        },
      });
    }

    // Location filter
    if (filters.location) {
      filter.push({
        geo_distance: {
          distance: `${filters.location.radiusKm}km`,
          location: {
            lat: filters.location.lat,
            lon: filters.location.lng,
          },
        },
      });
    }

    // Build sort
    const sortConfig = this.buildSort(sort, filters.location);

    // Build aggregations
    const aggregations = includeAggregations ? {
      categories: {
        terms: { field: 'category', size: 20 },
      },
      tags: {
        terms: { field: 'tags', size: 50 },
      },
      dateHistogram: {
        date_histogram: {
          field: 'createdAt',
          calendar_interval: 'month',
        },
      },
    } : undefined;

    // Execute search
    const result = await esClient.search({
      index: 'posts',
      query: {
        bool: { must, filter },
      },
      sort: sortConfig,
      from: (page - 1) * limit,
      size: limit,
      aggs: aggregations,
      highlight: {
        fields: {
          title: {},
          body: { fragment_size: 150, number_of_fragments: 2 },
        },
        pre_tags: ['<mark>'],
        post_tags: ['</mark>'],
      },
      suggest: query ? {
        text: query,
        phrase_suggestion: {
          phrase: {
            field: 'title',
            size: 3,
            gram_size: 3,
            direct_generator: [{
              field: 'title',
              suggest_mode: 'always',
            }],
          },
        },
      } : undefined,
    });

    // Format results
    const items = result.hits.hits.map(hit => ({
      ...hit._source,
      _score: hit._score,
      _highlight: hit.highlight,
    }));

    const suggestions = result.suggest?.phrase_suggestion?.[0]?.options
      ?.map((opt: any) => opt.text) || [];

    return {
      items,
      total: typeof result.hits.total === 'number'
        ? result.hits.total
        : result.hits.total?.value || 0,
      aggregations: result.aggregations,
      suggestions,
      took: result.took,
    };
  }

  // Autocomplete suggestions
  async autocomplete(
    query: string,
    options?: { limit?: number; type?: 'posts' | 'users' }
  ): Promise<Array<{ text: string; type: string; id?: string }>> {
    const { limit = 10, type } = options || {};

    const searches: any[] = [];

    // Search posts
    if (!type || type === 'posts') {
      searches.push({
        index: 'posts',
        query: {
          bool: {
            must: {
              multi_match: {
                query,
                fields: ['title.autocomplete^2', 'tags'],
                type: 'bool_prefix',
              },
            },
            filter: { term: { visibility: 'public' } },
          },
        },
        size: limit,
        _source: ['id', 'title'],
      });
    }

    // Search users
    if (!type || type === 'users') {
      searches.push({
        index: 'users',
        query: {
          multi_match: {
            query,
            fields: ['displayName.autocomplete', 'email.autocomplete'],
            type: 'bool_prefix',
          },
        },
        size: limit,
        _source: ['id', 'displayName', 'avatarUrl'],
      });
    }

    const results = await esClient.msearch({
      searches: searches.flatMap(s => [{ index: s.index }, s]),
    });

    const suggestions: Array<{ text: string; type: string; id?: string }> = [];

    results.responses.forEach((response: any, index: number) => {
      if (response.hits?.hits) {
        const searchType = index === 0 ? 'post' : 'user';
        response.hits.hits.forEach((hit: any) => {
          suggestions.push({
            text: searchType === 'post' ? hit._source.title : hit._source.displayName,
            type: searchType,
            id: hit._source.id,
          });
        });
      }
    });

    return suggestions.slice(0, limit);
  }

  // Search users
  async searchUsers(options: {
    query: string;
    page?: number;
    limit?: number;
  }): Promise<SearchResult<any>> {
    const { query, page = 1, limit = 20 } = options;

    const result = await esClient.search({
      index: 'users',
      query: {
        multi_match: {
          query,
          fields: [
            'displayName^3',
            'displayName.autocomplete^2',
            'email',
            'bio',
          ],
          fuzziness: 'AUTO',
        },
      },
      from: (page - 1) * limit,
      size: limit,
    });

    return {
      items: result.hits.hits.map(hit => ({
        ...hit._source,
        _score: hit._score,
      })),
      total: typeof result.hits.total === 'number'
        ? result.hits.total
        : result.hits.total?.value || 0,
      took: result.took,
    };
  }

  // Index a single document
  async indexDocument(index: string, id: string, document: any): Promise<void> {
    await esClient.index({
      index,
      id,
      document,
      refresh: true,
    });
  }

  // Update a document
  async updateDocument(index: string, id: string, updates: any): Promise<void> {
    await esClient.update({
      index,
      id,
      doc: updates,
      refresh: true,
    });
  }

  // Delete a document
  async deleteDocument(index: string, id: string): Promise<void> {
    await esClient.delete({
      index,
      id,
      refresh: true,
    });
  }

  // Bulk index documents
  async bulkIndex(index: string, documents: Array<{ id: string; doc: any }>): Promise<void> {
    const operations = documents.flatMap(({ id, doc }) => [
      { index: { _index: index, _id: id } },
      doc,
    ]);

    const result = await esClient.bulk({ operations, refresh: true });

    if (result.errors) {
      const errors = result.items
        .filter((item: any) => item.index?.error)
        .map((item: any) => item.index?.error);

      logger.error('Bulk index errors', { errors: errors.slice(0, 10) });
    }
  }

  private buildSort(
    sort: string,
    location?: { lat: number; lng: number; radiusKm: number }
  ): any[] {
    switch (sort) {
      case 'newest':
        return [{ createdAt: 'desc' }];
      case 'oldest':
        return [{ createdAt: 'asc' }];
      case 'popular':
        return [
          { likesCount: 'desc' },
          { commentsCount: 'desc' },
          { _score: 'desc' },
        ];
      case 'nearest':
        if (location) {
          return [{
            _geo_distance: {
              location: { lat: location.lat, lon: location.lng },
              order: 'asc',
              unit: 'km',
            },
          }];
        }
        return [{ _score: 'desc' }];
      case 'relevance':
      default:
        return [{ _score: 'desc' }, { createdAt: 'desc' }];
    }
  }
}

export const searchService = new SearchService();
```

### Data Synchronization

```typescript
// src/search/sync/postsSyncService.ts
import { db } from '../../database';
import { searchService } from '../../services/searchService';
import { logger } from '../../utils/logger';

export class PostsSyncService {
  // Sync a single post
  async syncPost(postId: string): Promise<void> {
    const post = await db('posts')
      .join('users', 'posts.user_id', 'users.id')
      .where('posts.id', postId)
      .whereNull('posts.deleted_at')
      .select(
        'posts.*',
        'users.id as author_id',
        'users.display_name as author_display_name',
        'users.avatar_url as author_avatar_url'
      )
      .first();

    if (!post) {
      // Post deleted, remove from index
      try {
        await searchService.deleteDocument('posts', postId);
      } catch (error) {
        // Ignore not found errors
      }
      return;
    }

    // Get tags
    const tags = await db('post_tags')
      .join('tags', 'tags.id', 'post_tags.tag_id')
      .where('post_tags.post_id', postId)
      .pluck('tags.name');

    const document = {
      id: post.id,
      userId: post.user_id,
      title: post.title,
      body: post.body,
      tags,
      category: post.category,
      visibility: post.visibility,
      likesCount: post.likes_count,
      commentsCount: post.comments_count,
      author: {
        id: post.author_id,
        displayName: post.author_display_name,
        avatarUrl: post.author_avatar_url,
      },
      location: post.location_lat && post.location_lng ? {
        lat: parseFloat(post.location_lat),
        lon: parseFloat(post.location_lng),
      } : null,
      createdAt: post.created_at,
      updatedAt: post.updated_at,
    };

    await searchService.indexDocument('posts', post.id, document);
  }

  // Full reindex of all posts
  async reindexAll(batchSize: number = 1000): Promise<void> {
    let offset = 0;
    let hasMore = true;

    logger.info('Starting full posts reindex');

    while (hasMore) {
      const posts = await db('posts')
        .join('users', 'posts.user_id', 'users.id')
        .whereNull('posts.deleted_at')
        .select(
          'posts.*',
          'users.id as author_id',
          'users.display_name as author_display_name',
          'users.avatar_url as author_avatar_url'
        )
        .orderBy('posts.id')
        .limit(batchSize)
        .offset(offset);

      if (posts.length === 0) {
        hasMore = false;
        continue;
      }

      // Get tags for all posts in batch
      const postIds = posts.map(p => p.id);
      const allTags = await db('post_tags')
        .join('tags', 'tags.id', 'post_tags.tag_id')
        .whereIn('post_tags.post_id', postIds)
        .select('post_tags.post_id', 'tags.name');

      const tagsByPost: Record<string, string[]> = {};
      for (const tag of allTags) {
        tagsByPost[tag.post_id] = tagsByPost[tag.post_id] || [];
        tagsByPost[tag.post_id].push(tag.name);
      }

      // Build documents
      const documents = posts.map(post => ({
        id: post.id,
        doc: {
          id: post.id,
          userId: post.user_id,
          title: post.title,
          body: post.body,
          tags: tagsByPost[post.id] || [],
          category: post.category,
          visibility: post.visibility,
          likesCount: post.likes_count,
          commentsCount: post.comments_count,
          author: {
            id: post.author_id,
            displayName: post.author_display_name,
            avatarUrl: post.author_avatar_url,
          },
          location: post.location_lat && post.location_lng ? {
            lat: parseFloat(post.location_lat),
            lon: parseFloat(post.location_lng),
          } : null,
          createdAt: post.created_at,
          updatedAt: post.updated_at,
        },
      }));

      await searchService.bulkIndex('posts', documents);

      offset += batchSize;
      logger.info(`Indexed ${offset} posts`);

      if (posts.length < batchSize) {
        hasMore = false;
      }
    }

    logger.info('Posts reindex complete');
  }
}

export const postsSyncService = new PostsSyncService();
```

## Algolia Implementation

```typescript
// src/services/algoliaService.ts
import algoliasearch, { SearchClient, SearchIndex } from 'algoliasearch';
import { config } from '../config';
import { logger } from '../utils/logger';

class AlgoliaService {
  private client: SearchClient;
  private postsIndex: SearchIndex;
  private usersIndex: SearchIndex;

  constructor() {
    this.client = algoliasearch(
      config.ALGOLIA_APP_ID!,
      config.ALGOLIA_API_KEY!
    );

    this.postsIndex = this.client.initIndex('posts');
    this.usersIndex = this.client.initIndex('users');

    // Configure indices
    this.configureIndices();
  }

  private async configureIndices(): Promise<void> {
    // Configure posts index
    await this.postsIndex.setSettings({
      searchableAttributes: [
        'title',
        'body',
        'tags',
        'author.displayName',
      ],
      attributesForFaceting: [
        'category',
        'tags',
        'visibility',
        'filterOnly(userId)',
      ],
      ranking: [
        'typo',
        'geo',
        'words',
        'filters',
        'proximity',
        'attribute',
        'exact',
        'custom',
      ],
      customRanking: [
        'desc(likesCount)',
        'desc(commentsCount)',
        'desc(createdAtTimestamp)',
      ],
      typoTolerance: true,
      minWordSizefor1Typo: 4,
      minWordSizefor2Typos: 8,
      queryLanguages: ['en'],
      removeStopWords: true,
      camelCaseAttributes: ['title'],
      highlightPreTag: '<mark>',
      highlightPostTag: '</mark>',
      snippetEllipsisText: '...',
      attributesToSnippet: ['body:50'],
    });

    // Configure users index
    await this.usersIndex.setSettings({
      searchableAttributes: [
        'displayName',
        'email',
        'bio',
      ],
      attributesForFaceting: [
        'filterOnly(status)',
      ],
      ranking: [
        'typo',
        'words',
        'filters',
        'proximity',
        'attribute',
        'exact',
        'custom',
      ],
      customRanking: [
        'desc(followersCount)',
      ],
    });

    logger.info('Algolia indices configured');
  }

  // Search posts
  async searchPosts(options: {
    query: string;
    userId?: string;
    filters?: {
      category?: string;
      tags?: string[];
      visibility?: string;
    };
    location?: { lat: number; lng: number; radiusKm: number };
    page?: number;
    limit?: number;
  }): Promise<any> {
    const { query, userId, filters = {}, location, page = 0, limit = 20 } = options;

    // Build filters
    const filterParts: string[] = [];

    if (filters.visibility) {
      filterParts.push(`visibility:${filters.visibility}`);
    } else if (userId) {
      filterParts.push(`(visibility:public OR userId:${userId})`);
    } else {
      filterParts.push('visibility:public');
    }

    if (filters.category) {
      filterParts.push(`category:${filters.category}`);
    }

    if (filters.tags && filters.tags.length > 0) {
      filterParts.push(`(${filters.tags.map(t => `tags:${t}`).join(' OR ')})`);
    }

    const searchParams: any = {
      query,
      filters: filterParts.join(' AND '),
      page,
      hitsPerPage: limit,
      attributesToRetrieve: [
        'objectID',
        'title',
        'body',
        'tags',
        'category',
        'author',
        'likesCount',
        'commentsCount',
        'createdAt',
      ],
      attributesToHighlight: ['title', 'body'],
      attributesToSnippet: ['body:50'],
      facets: ['category', 'tags'],
    };

    if (location) {
      searchParams.aroundLatLng = `${location.lat}, ${location.lng}`;
      searchParams.aroundRadius = location.radiusKm * 1000;
    }

    const result = await this.postsIndex.search(query, searchParams);

    return {
      items: result.hits.map((hit: any) => ({
        ...hit,
        id: hit.objectID,
        _highlight: hit._highlightResult,
        _snippet: hit._snippetResult,
      })),
      total: result.nbHits,
      page: result.page,
      totalPages: result.nbPages,
      facets: result.facets,
      took: result.processingTimeMS,
    };
  }

  // Autocomplete
  async autocomplete(query: string, limit: number = 10): Promise<any[]> {
    const results = await this.client.multipleQueries([
      {
        indexName: 'posts',
        query,
        params: {
          hitsPerPage: limit,
          attributesToRetrieve: ['title', 'objectID'],
          attributesToHighlight: ['title'],
        },
      },
      {
        indexName: 'users',
        query,
        params: {
          hitsPerPage: limit,
          attributesToRetrieve: ['displayName', 'avatarUrl', 'objectID'],
          attributesToHighlight: ['displayName'],
        },
      },
    ]);

    const suggestions: any[] = [];

    // Posts suggestions
    results.results[0].hits.forEach((hit: any) => {
      suggestions.push({
        text: hit.title,
        type: 'post',
        id: hit.objectID,
        highlight: hit._highlightResult?.title?.value,
      });
    });

    // Users suggestions
    results.results[1].hits.forEach((hit: any) => {
      suggestions.push({
        text: hit.displayName,
        type: 'user',
        id: hit.objectID,
        avatarUrl: hit.avatarUrl,
        highlight: hit._highlightResult?.displayName?.value,
      });
    });

    return suggestions.slice(0, limit);
  }

  // Index document
  async indexPost(post: any): Promise<void> {
    await this.postsIndex.saveObject({
      objectID: post.id,
      ...post,
      createdAtTimestamp: new Date(post.createdAt).getTime(),
      _geoloc: post.location ? {
        lat: post.location.lat,
        lng: post.location.lng,
      } : undefined,
    });
  }

  // Bulk index
  async bulkIndexPosts(posts: any[]): Promise<void> {
    const objects = posts.map(post => ({
      objectID: post.id,
      ...post,
      createdAtTimestamp: new Date(post.createdAt).getTime(),
      _geoloc: post.location ? {
        lat: post.location.lat,
        lng: post.location.lng,
      } : undefined,
    }));

    await this.postsIndex.saveObjects(objects);
  }

  // Delete document
  async deletePost(postId: string): Promise<void> {
    await this.postsIndex.deleteObject(postId);
  }

  // Partial update
  async updatePost(postId: string, updates: Partial<any>): Promise<void> {
    await this.postsIndex.partialUpdateObject({
      objectID: postId,
      ...updates,
    });
  }
}

export const algoliaService = new AlgoliaService();
```

### Search API Routes

```typescript
// src/routes/search.ts
import { Router } from 'express';
import { z } from 'zod';
import { searchService } from '../services/searchService';
import { algoliaService } from '../services/algoliaService';
import { optionalAuthenticate } from '../middleware/authenticate';
import { tieredRateLimiter } from '../middleware/tieredRateLimiter';
import { validateRequest } from '../middleware/validateRequest';
import { ApiResponseBuilder } from '../utils/response';
import { config } from '../config';

const router = Router();

const SearchSchema = z.object({
  q: z.string().min(1).max(200),
  category: z.string().optional(),
  tags: z.string().optional().transform(v => v?.split(',')),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
  lat: z.coerce.number().optional(),
  lng: z.coerce.number().optional(),
  radius: z.coerce.number().optional(),
  sort: z.enum(['relevance', 'newest', 'oldest', 'popular', 'nearest']).default('relevance'),
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(20),
});

// Main search endpoint
router.get('/',
  optionalAuthenticate,
  tieredRateLimiter('search'),
  validateRequest({ query: SearchSchema }),
  async (req, res) => {
    const params = req.query as z.infer<typeof SearchSchema>;

    const searchOptions = {
      query: params.q,
      userId: req.user?.id,
      filters: {
        category: params.category,
        tags: params.tags,
        dateFrom: params.dateFrom ? new Date(params.dateFrom) : undefined,
        dateTo: params.dateTo ? new Date(params.dateTo) : undefined,
        location: params.lat && params.lng ? {
          lat: params.lat,
          lng: params.lng,
          radiusKm: params.radius || 50,
        } : undefined,
      },
      sort: params.sort,
      page: params.page,
      limit: params.limit,
      includeAggregations: true,
    };

    // Use appropriate search provider
    const result = config.SEARCH_PROVIDER === 'algolia'
      ? await algoliaService.searchPosts(searchOptions)
      : await searchService.searchPosts(searchOptions);

    // Track search analytics
    await trackSearchQuery(params.q, result.total, req.user?.id);

    ApiResponseBuilder.success({
      results: result.items,
      facets: result.aggregations,
      suggestions: result.suggestions,
    })
      .withPagination({
        page: params.page,
        perPage: params.limit,
        total: result.total,
        totalPages: Math.ceil(result.total / params.limit),
        hasMore: params.page * params.limit < result.total,
      })
      .withMeta({ took: result.took })
      .send(res);
  }
);

// Autocomplete endpoint
router.get('/autocomplete',
  optionalAuthenticate,
  tieredRateLimiter('search'),
  async (req, res) => {
    const { q, limit = 10, type } = req.query;

    if (!q || typeof q !== 'string' || q.length < 2) {
      ApiResponseBuilder.success({ suggestions: [] }).send(res);
      return;
    }

    const suggestions = config.SEARCH_PROVIDER === 'algolia'
      ? await algoliaService.autocomplete(q, Number(limit))
      : await searchService.autocomplete(q, {
          limit: Number(limit),
          type: type as any,
        });

    ApiResponseBuilder.success({ suggestions }).send(res);
  }
);

// Search users
router.get('/users',
  optionalAuthenticate,
  tieredRateLimiter('search'),
  async (req, res) => {
    const { q, page = 1, limit = 20 } = req.query;

    if (!q || typeof q !== 'string') {
      ApiResponseBuilder.success({ results: [] }).send(res);
      return;
    }

    const result = await searchService.searchUsers({
      query: q,
      page: Number(page),
      limit: Number(limit),
    });

    ApiResponseBuilder.success({ results: result.items })
      .withPagination({
        page: Number(page),
        perPage: Number(limit),
        total: result.total,
        totalPages: Math.ceil(result.total / Number(limit)),
        hasMore: Number(page) * Number(limit) < result.total,
      })
      .send(res);
  }
);

// Track search for analytics
async function trackSearchQuery(
  query: string,
  resultsCount: number,
  userId?: string
): Promise<void> {
  await db('search_analytics').insert({
    query: query.toLowerCase(),
    results_count: resultsCount,
    user_id: userId,
    searched_at: new Date(),
  });
}

export { router as searchRouter };
```

## Gate Criteria

Before marking search functionality complete, verify:

### Infrastructure Gates
- [ ] Search engine (Elasticsearch/Algolia) connected
- [ ] Indices created with proper mappings
- [ ] Analyzers configured for text search
- [ ] Cluster health monitored

### Search Quality Gates
- [ ] Full-text search returns relevant results
- [ ] Typo tolerance working
- [ ] Autocomplete suggestions relevant
- [ ] Faceted filtering working
- [ ] Geo search working (if applicable)

### Synchronization Gates
- [ ] Real-time sync from database working
- [ ] Bulk reindex capability available
- [ ] Delete sync working
- [ ] Data consistency verified

### Performance Gates
- [ ] Search response time < 200ms p95
- [ ] Autocomplete response time < 100ms
- [ ] Rate limiting applied
- [ ] Caching implemented where appropriate

### Mobile Optimization Gates
- [ ] Response payload optimized
- [ ] Pagination working correctly
- [ ] Highlights included for UI display
- [ ] Offline search considered/documented

### Analytics Gates
- [ ] Search queries tracked
- [ ] Zero-result queries identified
- [ ] Popular searches available
- [ ] Search performance monitored
